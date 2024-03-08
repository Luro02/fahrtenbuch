use axum::Json;
use axum_messages::Messages;

use super::login::login;
use super::AuthBackendError;
use super::{AuthSession, RegistrationData};
use crate::response::ApiResult;

pub async fn register(
    auth_session: AuthSession,
    _messages: Messages,
    Json(data): Json<RegistrationData>,
) -> ApiResult<Option<()>> {
    // delegate to the backend to register the user
    match auth_session.backend.register(data.clone()).await {
        // after registering successfully, we can log in the user
        Ok(_) => login(auth_session, _messages, Json(data.credentials)).await,
        Err(AuthBackendError::UserAlreadyExists(username)) => {
            ApiResult::error(format!("User already exists: {}", username))
        }
        Err(error) => ApiResult::error(format!("Internal error: {}", error)),
    }
}
