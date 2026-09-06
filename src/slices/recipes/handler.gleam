// src/slices/recipes/handler.gleam
// HTTP handlers for recipes endpoints. Uses the service layer to perform
// business logic. This file contains Mist-agnostic handler functions — adapt
// the Request/Response wiring to your Mist version when integrating.

import infra.db.{Pool}
import ai.client_behaviour.{AiClient}
import slices.recipes.service.{generate_and_save}
import slices.recipes.models.{MealType}
import infra.otel.{with_span}
import infra.json.{decode_json_to_map, encode_to_json}

// Placeholder types until Mist types are wired
pub type Request
pub type Response

// Minimal JSON body parsing helpers (replace with Mist request body access)
external fn request_body_string(req: Request) -> String = "app" "request_body_string"
external fn response_json(status: Int, body: String) -> Response = "app" "response_json"

// Parse generate request body into needed fields
fn parse_generate_body(body_str: String) -> Result({user_id: Int, meal_type: MealType, include: List(String), exclude: List(String)}, String) {
  // We decode into a map<string, string|list> conventionally. The decode helper
  // returns a Map(String, String) for simple cases — replace with robust JSON
  // decoding in your integration.
  case decode_json_to_map(body_str) {
    Error(e) -> Error("invalid json: " ++ e)
    Ok(m) ->
      // Expect keys: user_id, meal_type, include, exclude. The map stores raw
      // string values for lists as comma-separated values in this scaffold.
      case Map.lookup(m, "user_id") {
        None -> Error("missing user_id")
        Some(user_id_s) ->
          case Int.from_string(user_id_s) {
            Error(_) -> Error("user_id must be integer")
            Ok(user_id) ->
              let mt = case Map.lookup(m, "meal_type") { None -> MealType.Lunch ; Some(s) -> if s == "dinner" { MealType.Dinner } else { MealType.Lunch } }
              let include = case Map.lookup(m, "include") { None -> [] ; Some(s) -> if s == "" { [] } else { String.split(s, ",") |> List.map(fn(x) { String.trim(x) }) } }
              let exclude = case Map.lookup(m, "exclude") { None -> [] ; Some(s) -> if s == "" { [] } else { String.split(s, ",") |> List.map(fn(x) { String.trim(x) }) } }
              Ok({ user_id: user_id, meal_type: mt, include: include, exclude: exclude })
          }
      }
  }
}

pub fn generate_handler(req: Request, pool: Pool, ai_client: AiClient) -> Response {
  with_span("http.recipes.generate", fn() {
    let body = request_body_string(req)
    case parse_generate_body(body) {
      Error(e) -> response_json(400, encode_to_json({"error" : e}))
      Ok(b) ->
        case generate_and_save(pool, ai_client, b.user_id, b.meal_type, b.include, b.exclude) {
          Ok(recipe) -> response_json(201, encode_to_json(recipe_to_map(recipe)))
          Error(e) -> response_json(500, encode_to_json({"error": e}))
        }
    }
  })
}

// Helper to convert typed Recipe record to a simple map for JSON encoding.
fn recipe_to_map(r) -> Map(String, String) {
  // For brevity, serialize only core fields as strings. Replace with a proper
  // JSON encoder for nested structures in production.
  Map.from_list([
    {"id", Int.to_string(r.id)},
    {"title", r.title},
    {"description", r.description},
    {"meal_type", case r.meal_type { MealType.Lunch -> "lunch" ; MealType.Dinner -> "dinner" }},
    {"likes", Int.to_string(r.likes)},
    {"dislikes", Int.to_string(r.dislikes)},
    {"ai_meta", r.ai_meta}
  ])
}

// TODO: Implement list_handler, get_handler, vote_handler similarly and mount
// routes in main.gleam when integrating with Mist or your HTTP framework.
