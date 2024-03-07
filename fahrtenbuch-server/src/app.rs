use std::str::FromStr;

use axum::Router;
use axum_login::{
    login_required,
    tower_sessions::{ExpiredDeletion, Expiry, SessionManagerLayer},
    AuthManagerLayerBuilder,
};
use axum_messages::MessagesManagerLayer;
use log::debug;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
use sqlx::SqlitePool;
use time::Duration;
use tokio::net::ToSocketAddrs;
use tokio::{signal, task::AbortHandle};
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use tower_sessions::cookie::SameSite;
use tower_sessions_sqlx_store::SqliteStore;

use crate::api;
use crate::auth::{self, AuthBackend};

pub struct App {
    db: SqlitePool,
}

impl App {
    /// Connect to the database and run migrations if necessary.
    pub async fn connect(database: &str) -> anyhow::Result<Self> {
        debug!(
            "Opening database {} with App running in {}",
            database,
            std::env::current_dir().unwrap().display()
        );
        let options = SqliteConnectOptions::from_str(database)?.create_if_missing(true);

        let db = SqlitePoolOptions::new()
            .max_connections(5)
            .connect_with(options)
            .await?;
        sqlx::migrate!().run(&db).await?;

        Ok(Self { db })
    }

    /// Serve the application.
    pub async fn serve(self, addr: impl ToSocketAddrs) -> anyhow::Result<()> {
        // Session layer.
        //
        // This uses `tower-sessions` to establish a layer that will provide the session
        // as a request extension.
        let session_store = SqliteStore::new(self.db.clone());
        session_store.migrate().await?;

        let deletion_task = tokio::task::spawn(
            session_store
                .clone()
                .continuously_delete_expired(tokio::time::Duration::from_secs(60)),
        );

        let session_layer = SessionManagerLayer::new(session_store)
            .with_secure(true)
            .with_same_site(SameSite::None)
            .with_expiry(Expiry::OnInactivity(Duration::days(1)));

        // Auth service.
        //
        // This combines the session layer with our backend to establish the auth
        // service which will provide the auth session as a request extension.
        let backend = AuthBackend::new(self.db);
        let auth_layer = AuthManagerLayerBuilder::new(backend, session_layer).build();

        // TODO: make api::router listen to /api/... instead of /...
        let app = Router::new()
            .merge(api::router())
            .route_layer(login_required!(AuthBackend, login_url = "/login"))
            .merge(auth::router())
            .layer(MessagesManagerLayer)
            .layer(auth_layer)
            .layer(CorsLayer::very_permissive())
            .layer(TraceLayer::new_for_http());

        let listener = tokio::net::TcpListener::bind(addr).await?;

        // Ensure we use a shutdown signal to abort the deletion task.
        axum::serve(listener, app.into_make_service())
            .with_graceful_shutdown(shutdown_signal(deletion_task.abort_handle()))
            .await?;

        deletion_task.await??;

        Ok(())
    }
}

async fn shutdown_signal(deletion_task_abort_handle: AbortHandle) {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => { deletion_task_abort_handle.abort() },
        _ = terminate => { deletion_task_abort_handle.abort() },
    }
}
