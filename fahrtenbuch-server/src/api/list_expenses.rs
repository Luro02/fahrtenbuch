use std::cmp::Reverse;
use std::collections::{HashMap, HashSet};

use axum::extract::Query;
use axum_messages::Messages;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::prelude::FromRow;
use sqlx::{QueryBuilder, SqlitePool};

use crate::auth::{AuthBackendError, AuthSession, UserId};
use crate::response::ApiResult;
use crate::utils::{self, SqlBuilderExt};

#[derive(Debug, Clone, Deserialize)]
pub struct ListExpensesOptions {
    #[serde(default)]
    pub start: Option<DateTime<Utc>>,
    #[serde(default)]
    pub end: Option<DateTime<Utc>>,
    /// Only list expenses for specific user(s).
    #[serde(default)]
    pub users: Vec<UserId>,
}

#[derive(Debug, Clone, FromRow)]
struct ExpenseEntry {
    id: i64,
    created_at: DateTime<Utc>,
    amount: i64,
    description: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Expense {
    pub id: i64,
    pub created_at: DateTime<Utc>,
    pub amount: i64,
    pub description: Option<String>,
    pub users: HashSet<UserId>,
}

impl Expense {
    /// Returns the amount of money the user has prepaid for the expense.
    pub fn amount_for(&self, user_id: UserId) -> u64 {
        if self.users.contains(&user_id) {
            let iterator = utils::divide_equally(self.amount as u64, self.users.len() as u64);
            let sorted_users = utils::sorted_vec(self.users.iter());

            iterator
                .zip(sorted_users)
                .find_map(
                    |(amount, uid)| {
                        if uid == &user_id {
                            Some(amount)
                        } else {
                            None
                        }
                    },
                )
                .unwrap_or_default()
        } else {
            0
        }
    }
}

async fn query_options(
    db: &SqlitePool,
    options: ListExpensesOptions,
) -> Result<Vec<Expense>, AuthBackendError> {
    let mut builder = QueryBuilder::new("select * from expenses");

    if let Some(start) = options.start {
        builder
            .push(" where datetime(created_at, 'utc') >= ")
            .push_bind(start);
    }

    if let Some(end) = options.end {
        builder
            .push(" and datetime(created_at, 'utc') <= ")
            .push_bind(end);
    }

    let trip_entries: Vec<ExpenseEntry> = builder.build_query_as().fetch_all(db).await?;

    let mut users_builder = QueryBuilder::new("select expense_id, user_id from expense_users");

    users_builder
        .push_in("expense_id", trip_entries.iter().map(|entry| entry.id))
        .push_in("user_id", options.users);

    // expense_id, users
    let mut expense_mapping: HashMap<i64, HashSet<i64>> = users_builder
        .build_query_as::<'_, (i64, i64)>()
        .fetch_all(db)
        .await?
        .into_iter()
        .fold(HashMap::new(), |mut map, (expense_id, user_id)| {
            map.entry(expense_id).or_default().insert(user_id);
            map
        });

    let mut result = Vec::new();
    for entry in trip_entries {
        let users = expense_mapping.remove(&entry.id).unwrap_or_default();
        result.push(Expense {
            id: entry.id,
            created_at: entry.created_at,
            amount: entry.amount,
            description: entry.description,
            users,
        });
    }

    result.sort_by_cached_key(|element| Reverse(element.created_at));

    Ok(result)
}

pub async fn list_expenses(
    auth_session: AuthSession,
    _messages: Messages,
    Query(options): Query<ListExpensesOptions>,
) -> ApiResult<Vec<Expense>> {
    match query_options(auth_session.backend.db().await, options).await {
        Ok(data) => ApiResult::ok(data),
        Err(e) => ApiResult::error(format!("Failed to list_expenses: {:?}", e)),
    }
}
