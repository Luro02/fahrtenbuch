use axum::Json;
use axum::{http::StatusCode, response::IntoResponse};
use axum_messages::Messages;

use super::{AuthSession, Credentials};
use crate::response;

pub async fn login(
    mut auth_session: AuthSession,
    messages: Messages,
    Json(creds): Json<Credentials>,
) -> impl IntoResponse {
    let user = match auth_session.authenticate(creds.clone()).await {
        Ok(Some(user)) => user,
        Ok(None) => {
            messages.error("Invalid credentials");

            return response::error("Invalid credentials".to_string()).into_response();
        }
        Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    };

    if auth_session.login(&user).await.is_err() {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    }

    messages.success(format!("Successfully logged in as {}", user.username));

    response::empty().into_response()
}
