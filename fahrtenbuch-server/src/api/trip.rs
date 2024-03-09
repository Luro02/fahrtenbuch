use std::collections::HashSet;

use chrono::DateTime;
use chrono::Utc;
use serde::{Deserialize, Serialize};

use crate::auth::UserId;
use crate::utils;

/// This represents an entry in the fahrtenbuch with all the relevant data.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Trip {
    /// The unique identifier for the trip.
    pub id: i64,
    /// The date when the entry was made.
    pub created_at: DateTime<Utc>,
    /// The start value of the odometer.
    pub start: u64,
    /// The value of the odometer at the end of the trip.
    pub end: u64,
    /// The reason for the trip.
    pub description: Option<String>,
    /// The associated users for the trip (who pays for the trip?)
    pub users: HashSet<UserId>,
    /// The price of the trip.
    pub price: u64,
}

impl Trip {
    pub fn distance(&self) -> u64 {
        self.end - self.start
    }

    pub fn distance_for(&self, user_id: UserId) -> u64 {
        utils::divide_equally(self.distance(), self.users.len() as u64)
            .zip(utils::sorted_vec(self.users.clone()))
            .find(|(_, uid)| *uid == user_id)
            .map(|(distance, _)| distance)
            .unwrap_or(0)
    }
}
