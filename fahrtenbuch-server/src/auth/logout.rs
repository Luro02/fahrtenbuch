use super::AuthSession;
use crate::response::ApiResult;

pub async fn logout(mut auth_session: AuthSession) -> ApiResult<Option<()>> {
    if let Err(error) = auth_session.logout().await {
        return ApiResult::error(format!("Internal error: {}", error));
    }

    ApiResult::empty()
}
