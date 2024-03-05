use axum::response::IntoResponse;

use super::AuthSession;
use crate::response;

pub async fn logout(mut auth_session: AuthSession) -> impl IntoResponse {
    if let Err(error) = auth_session.logout().await {
        return response::error(format!("Internal error: {}", error)).into_response();
    }

    response::empty().into_response()
}
