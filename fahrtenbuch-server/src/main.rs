mod api;
mod app;
mod auth;
mod response;
mod username;
pub(crate) mod utils;

use std::env;
use std::ffi::OsStr;

use log::error;

use app::App;

fn set_env_if_absent<K: AsRef<OsStr>, V: AsRef<OsStr>>(var: K, default: impl FnOnce() -> V) {
    if env::var(var.as_ref()).is_err() {
        env::set_var(var, default());
    }
}

#[tokio::main]
async fn main() {
    set_env_if_absent("RUST_APP_LOG", || "trace");
    set_env_if_absent("ADDR", || "127.0.0.1:3000");
    color_backtrace::install();
    pretty_env_logger::init_custom_env("RUST_APP_LOG");

    if let Err(e) = run().await {
        error!("{:?}", e);
        ::std::process::exit(1);
    }
}

async fn run() -> anyhow::Result<()> {
    let app = App::connect("sqlite:data.db").await?;
    //let app = App::connect("sqlite::memory:").await?;
    app.serve(env::var("ADDR")?).await?;

    Ok(())
}
