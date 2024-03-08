use axum::Json;
use axum_messages::Messages;

use super::{AuthSession, Credentials};
use crate::response::ApiResult;

pub async fn login(
    mut auth_session: AuthSession,
    messages: Messages,
    Json(creds): Json<Credentials>,
) -> ApiResult<Option<()>> {
    let user = match auth_session.authenticate(creds).await {
        Ok(Some(user)) => user,
        Ok(None) => {
            messages.error("Invalid credentials");

            return ApiResult::error("Failed to login: Invalid credentials".to_string());
        }
        Err(_) => return ApiResult::error("Failed to login.".to_string()),
    };

    if let Err(err) = auth_session.login(&user).await {
        return ApiResult::error(format!("Failed to login: {:?}", err));
    }

    messages.success(format!("Successfully logged in as {}", user.username));

    ApiResult::empty()
}
