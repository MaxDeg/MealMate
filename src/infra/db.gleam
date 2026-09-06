// src/infra/db.gleam
// Postgres pool and helpers using the `pog` driver (external bindings).
// This implementation provides a small, stable API that the slices use.
//
// API surface:
// - connect_from_env() -> Result(Pool, String)
// - query_one(pool, sql, params) -> Result(Row, String)
// - query_all(pool, sql, params) -> Result(List(Row), String)
// - execute(pool, sql, params) -> Result(Int, String)
// - with_transaction(pool, fn(conn) -> Result(a, String)) -> Result(a, String)

pub type Pool
pub type Conn
pub type Row

// External bindings to the Erlang `pog` driver. Replace the module/function
// names if your project's pog bindings differ. These external declarations
// make the runtime calls pluggable while keeping the Gleam surface typed.

// Connect returns an opaque pool handle. pool_size is optional and defaults to 10.
external fn pog_connect(url: String, pool_size: Int) -> Result(Pool, String) = "pog" "connect_pool"

// Execute a query that returns rows. Params are passed as a list of strings.
external fn pog_query(pool: Pool, sql: String, params: List(String)) -> Result(List(Row), String) = "pog" "query"

// Execute a statement that returns the number of affected rows.
external fn pog_execute(pool: Pool, sql: String, params: List(String)) -> Result(Int, String) = "pog" "execute"

// Run a function inside a DB transaction. The runtime binding should begin a
// transaction, call the function with a connection/context and commit/rollback.
external fn pog_transaction(pool: Pool, f: fn(Conn) -> Result(_, String)) -> Result(_, String) = "pog" "transaction"

// Convenience helpers for extracting values from Row. These are intentionally
// minimal — update to match how pog returns rows in your runtime.
external fn row_get_string(row: Row, column: Int) -> Result(String, String) = "pog" "row_get_string"
external fn row_get_int(row: Row, column: Int) -> Result(Int, String) = "pog" "row_get_int"
external fn row_get_jsonb(row: Row, column: Int) -> Result(String, String) = "pog" "row_get_jsonb"

// Utilities used by application code

pub fn connect_from_env() -> Result(Pool, String) {
  case System.get_env("DATABASE_URL") {
    None -> Error("DATABASE_URL not set")
    Some(url) -> {
      let pool_size =
        case System.get_env("POG_POOL_SIZE") {
          None -> 10
          Some(s) ->
            case Int.from_string(s) {
              Ok(i) -> i
              Error(_) -> 10
            }
        }
      pog_connect(url, pool_size)
    }
  }
}

pub fn query_one(pool: Pool, sql: String, params: List(String)) -> Result(Row, String) {
  case pog_query(pool, sql, params) {
    Ok(rows) ->
      case rows {
        [] -> Error("no rows returned")
        [first | _] -> Ok(first)
      }
    Error(e) -> Error(e)
  }
}

pub fn query_all(pool: Pool, sql: String, params: List(String)) -> Result(List(Row), String) {
  pog_query(pool, sql, params)
}

pub fn execute(pool: Pool, sql: String, params: List(String)) -> Result(Int, String) {
  pog_execute(pool, sql, params)
}

pub fn with_transaction(pool: Pool, f: fn(Conn) -> Result(_, String)) -> Result(_, String) {
  pog_transaction(pool, f)
}
