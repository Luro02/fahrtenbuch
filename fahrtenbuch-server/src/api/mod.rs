use axum::{
    routing::{get, post},
    Router,
};

mod add_expense;
mod add_trip;
mod list_expenses;
mod list_trips;
mod list_users;
mod summary;
mod trip;

pub fn router() -> Router<()> {
    Router::new()
        .route("/list_users", get(list_users::list_users))
        .route("/add_trip", post(add_trip::add_trip))
        .route("/list_trips", get(list_trips::list_trips))
        .route("/add_expense", post(add_expense::add_expense))
        .route("/list_expenses", get(list_expenses::list_expenses))
        .route("/summary", get(summary::summary))
}
