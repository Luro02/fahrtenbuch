FROM rust:1.76.0-slim-bullseye AS build

# View app name in Cargo.toml
ARG APP_NAME="fahrtenbuch-server"
ARG APP=/app/

WORKDIR /build

COPY Cargo.lock $APP
COPY Cargo.toml $APP

RUN mkdir src \
    && echo "// dummy file" > src/lib.rs \
    && cargo build --release

COPY migrations migrations
COPY src src
RUN cargo build --locked --release
RUN cp ./target/release/$APP_NAME /bin/server

FROM debian:bullseye-slim AS final

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "10001" \
    appuser
USER appuser

WORKDIR "/data"

COPY --from=build /bin/server /bin/
CMD ["/bin/server"]
