use axum::response::IntoResponse;
use axum::Json;
use axum_messages::Messages;

use super::login::login;
use super::AuthBackendError;
use super::{AuthSession, RegistrationData};
use crate::response;

pub async fn register(
    auth_session: AuthSession,
    _messages: Messages,
    Json(data): Json<RegistrationData>,
) -> impl IntoResponse {
    // delegate to the backend to register the user
    match auth_session.backend.register(data.clone()).await {
        // after registering successfully, we can log in the user
        Ok(_) => login(auth_session, _messages, Json(data.credentials))
            .await
            .into_response(),
        Err(AuthBackendError::UserAlreadyExists(username)) => {
            response::error(format!("User already exists: {}", username)).into_response()
        }
        // TODO: maybe return a 500 here
        Err(error) => response::error(format!("Internal error: {}", error)).into_response(),
    }
}
