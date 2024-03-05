use std::collections::HashMap;

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
    distance: u64,
    /// Total amount of money spent on expenses.
    prepaid: u64,
    total_amount: u64,
    /// How much each user has paid/must pay.
    balances: HashMap<UserId, i64>,
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

    let mut user_ids = users.into_iter().map(|(id, _)| id).collect::<Vec<_>>();
    user_ids.sort();

    let total_amount = expenses
        .iter()
        .map(|expense| expense.amount as u64)
        .sum::<u64>();

    let mut balances: HashMap<UserId, i64> = HashMap::new();

    // calculate the distance driven by each user:
    let distances = user_ids.iter().map(|id| {
        trips
            .iter()
            .map(|trip| trip.distance_for(*id) as u64)
            .sum::<u64>()
    });

    // the vec will be overwritten, the distances serve as weights for how much each user should pay
    let mut amount_to_pay = distances.collect::<Vec<_>>();
    let remainder = utils::divide_proportionally(total_amount, amount_to_pay.as_mut());

    // the user who drove the most should pay the remainder:
    let max_expense = *amount_to_pay.iter().max().unwrap();
    for expense in amount_to_pay.iter_mut() {
        if *expense == max_expense {
            *expense += remainder;
            break;
        }
    }

    // register the amount each user has to pay:
    for (id, amount) in user_ids.iter().zip(amount_to_pay.into_iter()) {
        *balances.entry(*id).or_default() -= amount as i64;
    }

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

    // TODO: instruct each user how much they have to send to whom to balance the expenses

    ApiResult::ok(SummaryResult {
        distance: trips
            .into_iter()
            .map(|trip| trip.distance_for(user))
            .sum::<u64>(),
        prepaid: 0,
        total_amount,
        balances,
    })
}
