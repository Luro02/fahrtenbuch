use std::collections::HashSet;

use axum::Json;
use axum_messages::Messages;

use chrono::Utc;
use serde::Deserialize;
use sqlx::SqlitePool;

use crate::auth::{AuthSession, UserId};
use crate::response::ApiResult;

#[derive(Debug, Clone, Deserialize)]
pub struct ExpenseData {
    amount: u64,
    #[serde(default)]
    description: Option<String>,
    users: HashSet<UserId>,
}

async fn query_add_expense(db: &SqlitePool, data: ExpenseData) -> anyhow::Result<()> {
    if data.users.is_empty() {
        return Err(anyhow::anyhow!("No users provided"));
    }

    let created_at = Utc::now();
    sqlx::query("insert into expenses (created_at, amount, description) values (?, ?, ?)")
        .bind(created_at)
        .bind(data.amount as i64)
        .bind(data.description)
        .execute(db)
        .await?;

    let (expense_id,): (i64,) =
        sqlx::query_as("select id from expenses where created_at = ? and amount = ?")
            .bind(created_at)
            .bind(data.amount as i64)
            .fetch_one(db)
            .await?;

    for user_id in data.users {
        sqlx::query("insert into expense_users (expense_id, user_id) values (?, ?)")
            .bind(expense_id)
            .bind(user_id)
            .execute(db)
            .await?;
    }

    Ok(())
}

pub async fn add_expense(
    auth_session: AuthSession,
    _messages: Messages,
    Json(data): Json<ExpenseData>,
) -> ApiResult<Option<()>> {
    match query_add_expense(auth_session.backend.db().await, data).await {
        Ok(_) => ApiResult::empty(),
        Err(e) => ApiResult::error(format!("Failed to add_trip: {:?}", e)),
    }
}
