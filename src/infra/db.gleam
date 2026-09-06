// src/infra/db.gleam
// Postgres pool and helpers using the `pog` driver.
// This file exposes a small, opinionated API used by slices:
// - connect_from_env() -> Result(Pool, String)
// - query_one(pool, sql, params) -> Result(Row, String)
// - query_all(pool, sql, params) -> Result(List(Row), String)
// - execute(pool, sql, params) -> Result(Int, String)
// - with_transaction(pool, fn(conn) -> Result(a, String)) -> Result(a, String)

// NOTE: This implementation assumes the pog driver is available as an Erlang
// library. The API used here is intentionally small so it is straightforward
// to adapt to the exact pog functions in your environment.

pub type Pool
pub type Conn
pub type Row

external fn getenv(key: String) -> Option(String) = "erlang" "getenv" // placeholder

pub fn connect_from_env() -> Result(Pool, String) {
  case getenv("DATABASE_URL") {
    None -> Error("DATABASE_URL not set")
    Some(url) -> {
      // Create a connection pool using pog. If pog is unavailable, replace
      // the implementation with the actual pog pool creation call.
      // TODO: Replace with pog:connect_pool or a real pool factory.
      // For now we return an opaque Pool to be wired later.
      Ok({})
    }
  }
}

pub fn query_one(_pool: Pool, _sql: String, _params: List(String)) -> Result(Row, String) {
  // TODO: Replace with actual pog query implementation.
  Error("Not implemented: query_one (wire pog query and parameter binding)")
}

pub fn query_all(_pool: Pool, _sql: String, _params: List(String)) -> Result(List(Row), String) {
  Error("Not implemented: query_all (wire pog query and parameter binding)")
}

pub fn execute(_pool: Pool, _sql: String, _params: List(String)) -> Result(Int, String) {
  Error("Not implemented: execute (wire pog exec and return affected row count)")
}

pub fn with_transaction(_pool: Pool, _f: fn(Conn) -> Result(_, String)) -> Result(_, String) {
  Error("Not implemented: with_transaction (open transaction on pog connection and run f)")
}
