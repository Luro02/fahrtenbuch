use axum::extract::Query;
use axum_messages::Messages;

use serde::Deserialize;

use crate::auth::{AuthSession, UserId};
use crate::response::ApiResult;
use crate::username::Username;

#[derive(Debug, Clone, Deserialize)]
pub struct ListUsersOptions {}

pub async fn list_users(
    auth_session: AuthSession,
    messages: Messages,
    Query(_options): Query<ListUsersOptions>,
) -> ApiResult<Vec<(UserId, Username)>> {
    match auth_session.backend.list_users().await {
        Ok(data) => {
            messages.success("Found users");
            ApiResult::ok(data)
        }
        Err(e) => {
            messages.error(format!("Failed to list users: {:?}", e));
            ApiResult::error(format!("Failed to read list: {:?}", e))
        }
    }
}
