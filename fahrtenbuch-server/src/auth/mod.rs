use axum::{
    routing::{get, post},
    Router,
};
use axum_login::AuthUser;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

mod backend;
pub use backend::*;

mod login;
mod logout;
mod register;

pub fn router() -> Router<()> {
    Router::new()
        .route("/login", post(login::login))
        // call this endpoint to register a new user and log in
        .route("/register", post(register::register))
        .route("/logout", get(logout::logout))
}

#[derive(Clone, Serialize, Deserialize, FromRow)]
pub struct User {
    id: i64,
    pub username: String,
    pub(super) password: String,
}

// Here we've implemented `Debug` manually to avoid accidentally logging the
// password hash.
impl std::fmt::Debug for User {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("User")
            .field("id", &self.id)
            .field("username", &self.username)
            .field("password", &"[redacted]")
            .finish()
    }
}

impl AuthUser for User {
    type Id = i64;

    fn id(&self) -> Self::Id {
        self.id
    }

    fn session_auth_hash(&self) -> &[u8] {
        self.password.as_bytes() // We use the password hash as the auth
                                 // hash--what this means
                                 // is when the user changes their password the
                                 // auth session becomes invalid.
    }
}

// This allows us to extract the authentication fields from forms. We use this
// to authenticate requests with the backend.
#[derive(Debug, Clone, Deserialize)]
pub struct Credentials {
    pub username: String,
    pub password: String,
}
