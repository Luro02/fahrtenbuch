use std::collections::HashSet;

use axum::Json;
use axum_messages::Messages;

use serde::Deserialize;
use sqlx::SqlitePool;

use crate::auth::{AuthSession, UserId};
use crate::response::ApiResult;

#[derive(Debug, Clone, Deserialize)]
pub struct ExpenseData {
    id: i64,
    #[serde(default)]
    amount: Option<u64>,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    users: HashSet<UserId>,
}

async fn query_update_expense(db: &SqlitePool, data: ExpenseData) -> anyhow::Result<()> {
    if let Some(amount) = data.amount {
        if amount == 0 {
            return Err(anyhow::anyhow!("The amount must be greater than 0"));
        }

        sqlx::query("update expenses set amount = ? where id = ?")
            .bind(amount as i64)
            .bind(data.id)
            .execute(db)
            .await?;
    }

    if let Some(description) = data.description {
        sqlx::query("update expenses set description = ? where id = ?")
            .bind(description)
            .bind(data.id)
            .execute(db)
            .await?;
    }

    if !data.users.is_empty() {
        sqlx::query("delete from expense_users where expense_id = ?")
            .bind(data.id)
            .execute(db)
            .await?;

        for user_id in data.users {
            sqlx::query("insert into expense_users (expense_id, user_id) values (?, ?)")
                .bind(data.id)
                .bind(user_id)
                .execute(db)
                .await?;
        }
    }

    Ok(())
}

pub async fn update_expense(
    auth_session: AuthSession,
    _messages: Messages,
    Json(data): Json<ExpenseData>,
) -> ApiResult<Option<()>> {
    match query_update_expense(auth_session.backend.db().await, data).await {
        Ok(_) => ApiResult::empty(),
        Err(e) => ApiResult::error(format!("Failed to update expense: {:?}", e)),
    }
}
