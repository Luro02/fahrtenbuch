use std::iter;

use sqlx::{Encode, QueryBuilder};

pub fn divide_equally(amount: u64, n: u64) -> impl Iterator<Item = u64> {
    let part = amount / n;
    let remainder = amount % n;

    iter::once(part + remainder).chain(iter::repeat(part).take((n - 1) as usize))
}

/// Divides the `numerator` into `N` parts, sized proportionally to the
/// `proportion` values in place. Returns the remainder.
///
/// The smaller the proportion, the smaller the amount that has to be paid.
pub fn divide_proportionally(numerator: u64, proportion: &mut [u64]) -> u64 {
    let total = {
        let mut total = 0;

        for i in 0..proportion.len() {
            total += proportion[i];
        }

        total
    };

    if total == 0 {
        for i in 0..proportion.len() {
            proportion[i] = 0;
        }

        return 0;
    }

    let mut remainder = numerator;

    for i in 0..proportion.len() {
        proportion[i] = (numerator * proportion[i]) / total;
        remainder -= proportion[i];
    }

    remainder
}

pub fn sorted_vec<T>(into_iter: impl IntoIterator<Item = T>) -> Vec<T>
where
    T: Ord,
{
    let mut vec: Vec<T> = into_iter.into_iter().collect();
    vec.sort();
    vec
}

pub trait SqlBuilderExt<'args, DB: sqlx::Database> {
    /// Add a constraint to the query that the field must be in the given values.
    ///
    /// If the given values are empty, this method does nothing.
    fn push_in<T>(&mut self, field: &str, values: impl IntoIterator<Item = T>) -> &mut Self
    where
        T: 'args + Encode<'args, DB> + Send + sqlx::Type<DB>;
}

impl<'args, DB: sqlx::Database> SqlBuilderExt<'args, DB> for QueryBuilder<'args, DB> {
    fn push_in<T>(&mut self, field: &str, values: impl IntoIterator<Item = T>) -> &mut Self
    where
        T: 'args + Encode<'args, DB> + Send + sqlx::Type<DB>,
    {
        let mut iterator = values.into_iter();
        let first_value = iterator.next();
        if first_value.is_none() {
            // nothing to constrain
            return self;
        }

        let mut separated = self.push(format!(" where {} in (", field)).separated(", ");

        if let Some(value) = first_value {
            separated.push_bind(value);
        }

        for value in iterator {
            separated.push_bind(value);
        }

        separated.push_unseparated(")");

        self
    }
}
