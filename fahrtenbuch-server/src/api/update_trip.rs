use std::collections::HashSet;

use axum::Json;
use axum_messages::Messages;

use serde::Deserialize;
use sqlx::SqlitePool;

use crate::api::add_trip::{validate_trip, TripValidationConfig};
use crate::api::list_trips::{list_trip_users, TripEntry};
use crate::api::trip::Trip;
use crate::auth::{AuthSession, UserId};
use crate::response::ApiResult;

#[derive(Debug, Clone, Deserialize)]
pub struct TripData {
    /// The end of the trip before the update.
    /// This is required to uniquely identify the trip.
    original_end: i64,
    #[serde(default)]
    start: Option<i64>,
    #[serde(default)]
    end: Option<i64>,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    users: HashSet<UserId>,
}

async fn query_update_trip(db: &SqlitePool, data: TripData) -> anyhow::Result<()> {
    let Some(current_trip_entry): Option<TripEntry> =
        sqlx::query_as("select * from trips where end = ?")
            .bind(data.original_end)
            .fetch_optional(db)
            .await?
    else {
        return Err(anyhow::anyhow!(
            "the trip with the end {} does not exist",
            data.original_end
        ));
    };

    let mut current_trip = Trip {
        id: current_trip_entry.id,
        created_at: current_trip_entry.created_at,
        start: current_trip_entry.start as u64,
        end: current_trip_entry.end as u64,
        description: current_trip_entry.description,
        users: HashSet::new(),
        price: 0,
    };

    current_trip.users = list_trip_users(db, [current_trip.id].into_iter(), vec![])
        .await?
        .into_iter()
        .map(|(_, user)| user)
        .collect();

    let mut trip_before: Option<TripEntry> = None;
    if let Some(start) = data.start {
        let original_start = current_trip.start as i64;
        current_trip.start = start as u64;

        trip_before = sqlx::query_as("select * from trips where end = ?")
            .bind(original_start)
            .fetch_optional(db)
            .await?;
    }

    trip_before = trip_before.filter(|before| before.end != current_trip.start as i64);
    if let Some(before) = trip_before.as_mut() {
        // we need to update the trip to end at the start of the current trip
        before.end = current_trip.start as i64;

        if before.end <= before.start {
            return Err(anyhow::anyhow!(
                "The trip before the current trip would become invalid: start = {} end = {}",
                before.start,
                before.end
            ));
        }
    }

    let mut trip_after: Option<TripEntry> = None;
    if let Some(end) = data.end {
        let original_end = current_trip.end as i64;
        current_trip.end = end as u64;

        trip_after = sqlx::query_as("select * from trips where start = ?")
            .bind(original_end)
            .fetch_optional(db)
            .await?;
    }

    trip_after = trip_after.filter(|after| after.start != current_trip.end as i64);
    if let Some(after) = trip_after.as_mut() {
        // we need to update the trip to start at the end of the current trip
        after.start = current_trip.end as i64;

        if after.end <= after.start {
            return Err(anyhow::anyhow!(
                "The trip after the current trip would become invalid: start = {} end = {}",
                after.start,
                after.end
            ));
        }
    }

    if let Some(description) = data.description {
        current_trip.description = Some(description);
    }

    if !data.users.is_empty() {
        current_trip.users = data.users.clone();
    }

    validate_trip(
        db,
        current_trip.clone(),
        TripValidationConfig {
            disable_start_check: false,
            ignore_id: Some(current_trip.id),
            ignore_gaps: true,
        },
    )
    .await?;

    if let Some(TripEntry { id, end, .. }) = trip_before {
        sqlx::query("update trips set end = ? where id = ?")
            .bind(end)
            .bind(id)
            .execute(db)
            .await?;
    }

    if let Some(TripEntry { id, start, .. }) = trip_after {
        sqlx::query("update trips set start = ? where id = ?")
            .bind(start)
            .bind(id)
            .execute(db)
            .await?;
    }

    sqlx::query("update trips set start = ?, end = ?, description = ? where id = ?")
        .bind(current_trip.start as i64)
        .bind(current_trip.end as i64)
        .bind(current_trip.description)
        .bind(current_trip.id)
        .execute(db)
        .await?;

    // update the users associated with the trip:
    if !data.users.is_empty() {
        sqlx::query("delete from trip_users where trip_id = ?")
            .bind(current_trip.id)
            .execute(db)
            .await?;

        for user_id in current_trip.users {
            sqlx::query("insert into trip_users (trip_id, user_id) values (?, ?)")
                .bind(current_trip.id)
                .bind(user_id)
                .execute(db)
                .await?;
        }
    }

    Ok(())
}

pub async fn update_trip(
    auth_session: AuthSession,
    _messages: Messages,
    Json(data): Json<TripData>,
) -> ApiResult<Option<()>> {
    match query_update_trip(auth_session.backend.db().await, data).await {
        Ok(_) => ApiResult::empty(),
        Err(e) => ApiResult::error(format!("Failed to update trip: {:?}", e)),
    }
}
