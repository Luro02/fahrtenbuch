use std::cmp::Reverse;
use std::collections::{HashMap, HashSet};

use axum::extract::Query;
use axum_messages::Messages;

use chrono::{DateTime, Utc};
use serde::Deserialize;
use sqlx::prelude::FromRow;
use sqlx::{QueryBuilder, SqlitePool};

use crate::api::trip::Trip;
use crate::auth::{AuthBackendError, AuthSession, UserId};
use crate::response::ApiResult;
use crate::utils::SqlBuilderExt;

#[derive(Debug, Clone, Deserialize)]
pub struct ListTripsOptions {
    #[serde(default)]
    pub start: Option<DateTime<Utc>>,
    #[serde(default)]
    pub end: Option<DateTime<Utc>>,
    /// Only list trips for specific user(s).
    #[serde(default)]
    pub users: Vec<UserId>,
}

#[derive(Debug, Clone, FromRow)]
pub struct TripEntry {
    pub id: i64,
    pub created_at: DateTime<Utc>,
    pub start: i64,
    pub end: i64,
    pub description: Option<String>,
}

const PRICE_PER_KM: f32 = 0.139;

pub async fn list_trip_users(
    db: &SqlitePool,
    trip_ids: impl Iterator<Item = i64>,
    users: Vec<UserId>,
) -> Result<Vec<(i64, UserId)>, AuthBackendError> {
    let mut users_builder = QueryBuilder::new("select trip_id, user_id from trip_users");

    users_builder
        .push_in("trip_id", trip_ids)
        .push_in("user_id", users);

    Ok(users_builder
        .build_query_as::<'_, (i64, i64)>()
        .fetch_all(db)
        .await?)
}

async fn query_options(
    db: &SqlitePool,
    options: ListTripsOptions,
) -> Result<Vec<Trip>, AuthBackendError> {
    let mut builder = QueryBuilder::new("select * from trips");

    if let Some(start) = options.start {
        builder
            .push(" where datetime(created_at, 'utc') >= ")
            .push_utc_bind(start);
    }

    if let Some(end) = options.end {
        builder
            .push(" and datetime(created_at, 'utc') <= ")
            .push_utc_bind(end);
    }

    let trip_entries: Vec<TripEntry> = builder.build_query_as().fetch_all(db).await?;

    // trip_id, users
    let mut trip_mapping: HashMap<i64, HashSet<i64>> =
        list_trip_users(db, trip_entries.iter().map(|entry| entry.id), options.users)
            .await?
            .into_iter()
            .fold(HashMap::new(), |mut map, (trip_id, user_id)| {
                map.entry(trip_id).or_default().insert(user_id);
                map
            });

    let mut result = Vec::new();
    for entry in trip_entries {
        let users = trip_mapping.remove(&entry.id).unwrap_or_default();
        result.push(Trip {
            id: entry.id,
            created_at: entry.created_at,
            start: entry.start as u64,
            end: entry.end as u64,
            description: entry.description,
            users,
            price: (((entry.end as u64 - entry.start as u64) as f32 * PRICE_PER_KM) * 100.0) as u64,
        });
    }

    result.sort_by_cached_key(|element| Reverse(element.end));

    Ok(result)
}

pub async fn list_trips(
    auth_session: AuthSession,
    _messages: Messages,
    Query(options): Query<ListTripsOptions>,
) -> ApiResult<Vec<Trip>> {
    match query_options(auth_session.backend.db().await, options).await {
        Ok(data) => ApiResult::ok(data),
        Err(e) => ApiResult::error(format!("Failed to list_trips: {:?}", e)),
    }
}
