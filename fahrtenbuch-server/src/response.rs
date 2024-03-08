use axum::response::{IntoResponse, Response};
use serde::Serialize;

pub enum ApiResult<T: Serialize, E: ToString = String> {
    Ok(T),
    Err(E),
}

impl<T: Serialize, E: ToString> ApiResult<T, E> {
    pub fn ok(data: T) -> Self {
        ApiResult::Ok(data)
    }

    pub fn error(message: E) -> Self {
        ApiResult::Err(message)
    }
}

impl<T: Serialize, E: ToString> ApiResult<Option<T>, E> {
    pub fn empty() -> Self {
        ApiResult::Ok(None)
    }
}

impl<T: Serialize, E: ToString> IntoResponse for ApiResult<T, E> {
    fn into_response(self) -> Response {
        match self {
            ApiResult::Ok(data) => axum::Json(serde_json::json!({
                "success": true,
                "data": data,
            }))
            .into_response(),
            ApiResult::Err(message) => axum::Json(serde_json::json!({
                "success": false,
                "message": message.to_string(),
            }))
            .into_response(),
        }
    }
}
