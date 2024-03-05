use async_trait::async_trait;
use axum_login::AuthnBackend;
use password_auth::verify_password;
use serde::Deserialize;
use sqlx::SqlitePool;
use tokio::task;

use super::{Credentials, User};

// We use a type alias for convenience.
//
// Note that we've supplied our concrete backend here.
pub type AuthSession = axum_login::AuthSession<AuthBackend>;
pub type UserId = axum_login::UserId<AuthBackend>;

#[derive(Debug, Clone)]
pub struct AuthBackend {
    db: SqlitePool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RegistrationData {
    #[serde(flatten)]
    pub credentials: Credentials,
}

impl AuthBackend {
    pub fn new(db: SqlitePool) -> Self {
        Self { db }
    }

    pub async fn db(&self) -> &SqlitePool {
        &self.db
    }

    pub async fn list_users(&self) -> Result<Vec<(UserId, String)>, AuthBackendError> {
        let result = sqlx::query_as("select id, username from users")
            .fetch_all(&self.db)
            .await?;

        Ok(result)
    }

    async fn get_user(&self, username: &str) -> Result<Option<User>, AuthBackendError> {
        let user = sqlx::query_as("select * from users where username = ?")
            .bind(username)
            .fetch_optional(&self.db)
            .await?;

        Ok(user)
    }

    pub async fn register(&self, data: RegistrationData) -> Result<(), AuthBackendError> {
        if let Some(user) = self.get_user(&data.credentials.username).await? {
            return Err(AuthBackendError::UserAlreadyExists(user.username));
        }

        let hashed_password =
            task::spawn_blocking(|| password_auth::generate_hash(data.credentials.password))
                .await?;

        sqlx::query("insert into users (username, password) values (?, ?)")
            .bind(data.credentials.username)
            .bind(hashed_password)
            .execute(&self.db)
            .await?;

        Ok(())
    }
}

#[derive(Debug, thiserror::Error)]
pub enum AuthBackendError {
    #[error(transparent)]
    Sqlx(#[from] sqlx::Error),
    #[error(transparent)]
    TaskJoin(#[from] task::JoinError),
    #[error("The user '{0}' already exists")]
    UserAlreadyExists(String),
}

#[async_trait]
impl AuthnBackend for AuthBackend {
    type User = User;
    type Credentials = Credentials;
    type Error = AuthBackendError;

    async fn authenticate(
        &self,
        creds: Self::Credentials,
    ) -> Result<Option<Self::User>, Self::Error> {
        let user: Option<Self::User> = sqlx::query_as("select * from users where username = ? ")
            .bind(creds.username)
            .fetch_optional(&self.db)
            .await?;

        // Verifying the password is blocking and potentially slow, so we'll do so via
        // `spawn_blocking`.
        task::spawn_blocking(|| {
            // We're using password-based authentication--this works by comparing our form
            // input with an argon2 password hash.
            Ok(user.filter(|user| verify_password(creds.password, &user.password).is_ok()))
        })
        .await?
    }

    async fn get_user(&self, user_id: &UserId) -> Result<Option<Self::User>, Self::Error> {
        let user = sqlx::query_as("select * from users where id = ?")
            .bind(user_id)
            .fetch_optional(&self.db)
            .await?;

        Ok(user)
    }
}
