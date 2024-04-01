use std::collections::HashSet;

use axum::Json;
use axum_messages::Messages;

use chrono::{DateTime, Utc};
use serde::Deserialize;
use sqlx::SqlitePool;

use crate::api::trip::Trip;
use crate::auth::{AuthSession, UserId};
use crate::response::ApiResult;

#[derive(Debug, Clone, Deserialize)]
pub struct TripData {
    #[serde(default)]
    created_at: Option<DateTime<Utc>>,
    start: i64,
    end: i64,
    #[serde(default)]
    description: Option<String>,
    users: HashSet<UserId>,
    #[serde(default)]
    disable_start_check: bool,
}

#[derive(Debug, Clone, Default)]
pub struct TripValidationConfig {
    pub disable_start_check: bool,
    pub ignore_id: Option<i64>,
    pub ignore_gaps: bool,
}

/// Ensures that the provided trip will be valid in the database.
pub async fn validate_trip(
    db: &SqlitePool,
    trip: Trip,
    config: TripValidationConfig,
) -> anyhow::Result<()> {
    if trip.users.is_empty() {
        return Err(anyhow::anyhow!(
            "A trip must have at least one user associated with it"
        ));
    }

    if trip.start >= trip.end {
        return Err(anyhow::anyhow!(
            "The start {} must be before the end {}",
            trip.start,
            trip.end
        ));
    }

    // check that for a start value, there is a trip with that end value
    //
    // this prevents gaps like:
    //
    // 0 - 3
    // 4 - 6
    //
    // (here the trip 3 - 4 is missing)
    if trip.start > 0 && !config.disable_start_check && !config.ignore_gaps {
        let value: Option<(i64,)> =
            sqlx::query_as("select id from trips where end = ? and id != ?")
                .bind(trip.start as i64)
                .bind(config.ignore_id.unwrap_or(-1))
                .fetch_optional(db)
                .await?;

        if value.is_none() {
            return Err(anyhow::anyhow!(
                "The start value {} is not connected to any end value",
                trip.start
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
    if !config.ignore_gaps {
        let value: Option<(i64,)> =
            sqlx::query_as("select id from trips where (end > ? or start = ?) and id != ?")
                .bind(trip.start as i64)
                .bind(trip.start as i64)
                .bind(config.ignore_id.unwrap_or(-1))
                .fetch_optional(db)
                .await?;

        if value.is_some() {
            return Err(anyhow::anyhow!(
                "The start value {} is conflicting with another trip",
                trip.start
            ));
        }
    }

    Ok(())
}

async fn query_add_trip(db: &SqlitePool, data: TripData) -> anyhow::Result<()> {
    validate_trip(
        db,
        Trip {
            id: 0,
            created_at: data.created_at.unwrap_or_else(|| Utc::now()),
            start: data.start as u64,
            end: data.end as u64,
            description: data.description.clone(),
            users: data.users.clone(),
            price: 0,
        },
        TripValidationConfig {
            disable_start_check: data.disable_start_check,
            ..Default::default()
        },
    )
    .await?;

    sqlx::query("insert into trips (created_at, start, end, description) values (?, ?, ?, ?)")
        .bind(data.created_at.unwrap_or_else(|| Utc::now()))
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
