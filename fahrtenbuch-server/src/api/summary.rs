use std::collections::{BTreeMap, HashMap};

use axum::extract::Query;
use axum_messages::Messages;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::api::list_expenses::{list_expenses, ListExpensesOptions};
use crate::api::list_trips::{list_trips, ListTripsOptions};
use crate::api::list_users::{list_users, ListUsersOptions};
use crate::auth::{AuthSession, UserId};
use crate::response::ApiResult;
use crate::utils;

#[derive(Debug, Clone, Deserialize)]
pub struct SummaryOptions {
    #[serde(default)]
    start: Option<DateTime<Utc>>,
    #[serde(default)]
    end: Option<DateTime<Utc>>,
    user: UserId,
}

#[derive(Debug, Clone, Serialize)]
pub struct SummaryResult {
    /// How much the user has driven in the given time frame.
    distance: u64,
    /// Amount of money the user prepaid for expenses.
    prepaid: u64,
    total_amount: u64,
    /// The distance driven by all users in the given time frame.
    total_distance: u64,
    /// How much each user has paid/must pay.
    balances: HashMap<UserId, i64>,
    /// How much the user gets or must pay to whom to balance the expenses.
    payments: HashMap<UserId, HashMap<UserId, i64>>,
}

macro_rules! min {
    ($e:expr) => {
        $e
    };
    ( $first:expr $(, $e:expr)+ ) => {
        ::core::cmp::min($first, min!($($e),*))
    };
}

fn calculate_payments(balances: HashMap<UserId, i64>) -> HashMap<UserId, HashMap<UserId, i64>> {
    // calculate the amount each user has to pay to whom to balance the expenses
    let mut payments = HashMap::new();

    let sorted_balances: BTreeMap<UserId, i64> = BTreeMap::from_iter(balances.clone().into_iter());
    // we need to keep track of the updated balances separately,
    // because we can't modify the balances while iterating over them
    let mut updated_balances = sorted_balances.clone();

    for (user_id, mut amount) in sorted_balances {
        // skip users who are already balanced or have a positive balance
        if amount >= 0 {
            continue;
        }

        // now find all users who get paid
        let people_with_positive_balance = updated_balances
            .clone()
            .into_iter()
            .filter(|(_, amount)| *amount > 0);

        let payments_of_user: &mut HashMap<UserId, i64> = payments.entry(user_id).or_default();

        // iterate over the users and pay each one as much as possible until the amount is 0
        for (user_to_pay, their_balance) in people_with_positive_balance {
            let payment = payments_of_user.entry(user_to_pay).or_default();

            // either pay their full balance or the amount the user owes
            *payment = min!(amount.abs(), their_balance);
            amount += *payment;
            updated_balances.insert(user_to_pay, their_balance - *payment);

            // if we have paid the full amount, we can stop
            if amount == 0 {
                break;
            }
        }
    }

    payments
}

pub async fn summary(
    auth_session: AuthSession,
    messages: Messages,
    Query(SummaryOptions { start, end, user }): Query<SummaryOptions>,
) -> ApiResult<SummaryResult> {
    let trips = match list_trips(
        auth_session.clone(),
        messages.clone(),
        Query(ListTripsOptions {
            start,
            end,
            users: vec![],
        }),
    )
    .await
    {
        ApiResult::Ok(data) => data,
        ApiResult::Err(e) => return ApiResult::error(e.to_string()),
    };

    let expenses = match list_expenses(
        auth_session.clone(),
        messages.clone(),
        Query(ListExpensesOptions {
            start,
            end,
            users: vec![],
        }),
    )
    .await
    {
        ApiResult::Ok(data) => data,
        ApiResult::Err(e) => return ApiResult::error(e.to_string()),
    };

    let users = match list_users(auth_session, messages, Query(ListUsersOptions {})).await {
        ApiResult::Ok(data) => data,
        ApiResult::Err(e) => return ApiResult::error(e.to_string()),
    };

    // sort the user ids to ensure that we always get the same result
    let mut user_ids = users.into_iter().map(|(id, _)| id).collect::<Vec<_>>();
    user_ids.sort();

    // the total amount of money spent on expenses in the given time frame
    let total_amount = expenses
        .iter()
        .map(|expense| expense.amount as u64)
        .sum::<u64>();

    // calculate the distance driven by each user:
    let distances = user_ids.iter().map(|id| {
        trips
            .iter()
            .map(|trip| trip.distance_for(*id) as u64)
            .sum::<u64>()
    });

    // the vec will be overwritten, the distances serve as weights for how much each user should pay
    let mut amount_to_pay = distances.collect::<Vec<_>>();
    // calculate the total distance driven by all users
    let total_distance = amount_to_pay.iter().sum::<u64>();
    let remainder = utils::divide_proportionally(total_amount, amount_to_pay.as_mut());

    // the user who drove the most should pay the remainder:
    let max_expense = *amount_to_pay.iter().max().unwrap();
    for expense in amount_to_pay.iter_mut() {
        if *expense == max_expense {
            *expense += remainder;
            break;
        }
    }

    let mut balances: HashMap<UserId, i64> = HashMap::new();

    // register the amount each user has to pay:
    for (id, amount) in user_ids.iter().zip(amount_to_pay.into_iter()) {
        *balances.entry(*id).or_default() -= amount as i64;
    }

    let prepaid = expenses
        .iter()
        .map(|expense| expense.amount_for(user) as u64)
        .sum();

    // for each expense, add the amount to the balance of the users who prepaid them
    for expense in expenses {
        // add the amount to the balance of the users who prepaid the expense
        for (amount, user_id) in
            utils::divide_equally(expense.amount as u64, expense.users.len() as u64)
                // we need to sort the users to ensure that the balance is deterministic
                .zip(utils::sorted_vec(expense.users.iter()).into_iter())
        {
            *balances.entry(*user_id).or_default() += amount as i64;
        }
    }

    // Suppose we have the following balances:
    //
    // A: -10
    // B: 5
    // C: 25
    // D: -20
    //
    // Then A has to pay 5 to B and 5 to C

    ApiResult::ok(SummaryResult {
        distance: trips
            .into_iter()
            .map(|trip| trip.distance_for(user))
            .sum::<u64>(),
        prepaid,
        total_distance,
        total_amount,
        balances: balances.clone(),
        payments: calculate_payments(balances),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    use map_macro::hash_map;
    use pretty_assertions::assert_eq;

    #[test]
    fn test_calculate_payments_two_negative() {
        let balances = vec![-10, 5, 25, -20]
            .into_iter()
            .enumerate()
            .map(|(i, amount)| (i as i64, amount))
            .collect::<HashMap<UserId, i64>>();

        assert_eq!(
            hash_map! {
                0 => hash_map! {
                    1 => 5,
                    2 => 5,
                },
                3 => hash_map! {
                    2 => 20,
                },
            },
            calculate_payments(balances)
        );
    }

    #[test]
    fn test_calculate_payments_one_negative() {
        let balances = vec![-30, 5, 25]
            .into_iter()
            .enumerate()
            .map(|(i, amount)| (i as i64, amount))
            .collect::<HashMap<UserId, i64>>();

        assert_eq!(
            hash_map! {
                0 => hash_map! {
                    1 => 5,
                    2 => 25,
                }
            },
            calculate_payments(balances)
        );
    }

    #[test]
    fn test_calculate_payments_worst_case() {
        let balances = vec![-1, -2, -3, -4, 10]
            .into_iter()
            .enumerate()
            .map(|(i, amount)| (i as i64, amount))
            .collect::<HashMap<UserId, i64>>();

        assert_eq!(
            hash_map! {
                0 => hash_map! {
                    4 => 1,
                },
                1 => hash_map! {
                    4 => 2,
                },
                2 => hash_map! {
                    4 => 3,
                },
                3 => hash_map! {
                    4 => 4,
                },
            },
            calculate_payments(balances)
        );
    }
}
