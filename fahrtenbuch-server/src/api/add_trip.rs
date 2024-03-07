use std::collections::HashSet;

use axum::Json;
use axum_messages::Messages;

use chrono::Utc;
use serde::Deserialize;
use sqlx::SqlitePool;

use crate::auth::{AuthSession, UserId};
use crate::response::ApiResult;

#[derive(Debug, Clone, Deserialize)]
pub struct TripData {
    start: i64,
    end: i64,
    #[serde(default)]
    description: Option<String>,
    users: HashSet<UserId>,
    #[serde(default)]
    disable_start_check: bool,
}

async fn query_add_trip(db: &SqlitePool, data: TripData) -> anyhow::Result<()> {
    if data.users.is_empty() {
        return Err(anyhow::anyhow!("No users provided"));
    }

    if data.start >= data.end {
        return Err(anyhow::anyhow!(
            "The start {} must be before the end {}",
            data.start,
            data.end
        ));
    }

    if data.start > 0 && !data.disable_start_check {
        let value: Option<(i64,)> = sqlx::query_as("select id from trips where end = ?")
            .bind(data.start)
            .fetch_optional(db)
            .await?;

        if value.is_none() {
            return Err(anyhow::anyhow!(
                "The start value {} is not connected to any end value",
                data.start
            ));
        }
    }

    // What is not ok:
    //   0 - 150
    //
    // 150 - 200
    // 150 - 250
    //
    // 100 - 200 <- how would that be possible?

    // check that the trip is not conflicting with another trip in the database:
    let value: Option<(i64,)> = sqlx::query_as("select id from trips where end > ? or start = ?")
        .bind(data.start)
        .bind(data.start)
        .fetch_optional(db)
        .await?;

    if value.is_some() {
        return Err(anyhow::anyhow!(
            "The start value {} is conflicting with another trip",
            data.start
        ));
    }

    sqlx::query("insert into trips (created_at, start, end, description) values (?, ?, ?, ?)")
        .bind(Utc::now())
        .bind(data.start)
        .bind(data.end)
        .bind(data.description)
        .execute(db)
        .await?;

    let (trip_id,): (i64,) = sqlx::query_as("select id from trips where start = ? and end = ?")
        .bind(data.start)
        .bind(data.end)
        .fetch_one(db)
        .await?;

    for user_id in data.users {
        sqlx::query("insert into trip_users (trip_id, user_id) values (?, ?)")
            .bind(trip_id)
            .bind(user_id)
            .execute(db)
            .await?;
    }

    Ok(())
}

pub async fn add_trip(
    auth_session: AuthSession,
    _messages: Messages,
    Json(data): Json<TripData>,
) -> ApiResult<Option<()>> {
    match query_add_trip(auth_session.backend.db().await, data).await {
        Ok(_) => ApiResult::empty(),
        Err(e) => ApiResult::error(format!("Failed to add_trip: {:?}", e)),
    }
}
