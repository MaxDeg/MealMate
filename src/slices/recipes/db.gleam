// src/slices/recipes/db.gleam
// Squirrel-style queries for recipes slice using the pog-backed infra.db helpers.
// This is a pragmatic implementation that constructs parameterized SQL and
// maps rows into typed Recipe records. Replace the simple JSON helpers with a
// proper JSON encoder (e.g., jiffy/jsx) in production.

import infra.db.{Pool, query_one, query_all, execute, row_get_int, row_get_string, row_get_jsonb}
import slices.recipes.models.{Recipe}
import ai.client_behaviour.{Ingredient}

// Simple helpers to convert ingredients and steps to JSON strings.
// TODO: Replace with a real JSON serializer.
fn ingredients_to_json(ingredients: List(Ingredient)) -> String {
  let items =
    ingredients
    |> List.map(fn(i) {
      // naive JSON object for each ingredient
      "{\"name\":\"" ++ i.name ++ "\",\"quantity\":\"" ++ i.quantity ++ "\"}"
    })
    |> String.join(",")
  "[" ++ items ++ "]"
}

fn steps_to_json(steps: List(String)) -> String {
  let items = steps |> List.map(fn(s) { "\"" ++ s ++ "\"" }) |> String.join(",")
  "[" ++ items ++ "]"
}

pub fn insert_recipe(pool: Pool, title: String, description: String, ingredients: List(Ingredient), steps: List(String), meal_type: String, ai_meta_json: String) -> Result(Recipe, String) {
  let ingredients_json = ingredients_to_json(ingredients)
  let steps_json = steps_to_json(steps)
  let sql = "INSERT INTO recipes (title, description, ingredients, steps, meal_type, ai_meta) VALUES ($1, $2, $3::jsonb, $4::jsonb, $5, $6::jsonb) RETURNING id, title, description, ingredients, steps, meal_type, likes_count, dislikes_count, ai_meta"
  let params = [title, description, ingredients_json, steps_json, meal_type, ai_meta_json]
  case query_one(pool, sql, params) {
    Ok(row) -> row_to_recipe(row)
    Error(e) -> Error(e)
  }
}

pub fn get_recipe_by_id(pool: Pool, id: Int) -> Result(Recipe, String) {
  let sql = "SELECT id, title, description, ingredients, steps, meal_type, likes_count, dislikes_count, ai_meta FROM recipes WHERE id = $1"
  case query_one(pool, sql, [Int.to_string(id)]) {
    Ok(row) -> row_to_recipe(row)
    Error(e) -> Error(e)
  }
}

pub fn list_recipes_for_user(pool: Pool, _user_id: Int, _meal_type: Option(String), limit: Int, offset: Int) -> Result(List(Recipe), String) {
  // For now, ignore user preferences & return recent recipes. Extend later to
  // filter by user preferences and personalization.
  let sql = "SELECT id, title, description, ingredients, steps, meal_type, likes_count, dislikes_count, ai_meta FROM recipes ORDER BY inserted_at DESC LIMIT $1 OFFSET $2"
  case query_all(pool, sql, [Int.to_string(limit), Int.to_string(offset)]) {
    Ok(rows) -> Ok(rows |> List.map(fn(r) { case row_to_recipe(r) { Ok(recipe) -> recipe ; Error(_) -> Recipe(0, "", "", [], [], "", 0, 0, "") } }))
    Error(e) -> Error(e)
  }
}

pub fn upsert_vote(pool: Pool, user_id: Int, recipe_id: Int, value: Int) -> Result((), String) {
  // Insert or update the vote, then update aggregates in recipes table.
  // value expected: 1 (like) or -1 (dislike)
  let upsert_sql = "INSERT INTO recipe_votes (user_id, recipe_id, value) VALUES ($1, $2, $3) ON CONFLICT (user_id, recipe_id) DO UPDATE SET value = EXCLUDED.value"
  let agg_sql = "UPDATE recipes SET likes_count = (SELECT COALESCE(SUM(CASE WHEN value = 1 THEN 1 ELSE 0 END),0) FROM recipe_votes WHERE recipe_id = $1), dislikes_count = (SELECT COALESCE(SUM(CASE WHEN value = -1 THEN 1 ELSE 0 END),0) FROM recipe_votes WHERE recipe_id = $1) WHERE id = $1"
  case execute(pool, upsert_sql, [Int.to_string(user_id), Int.to_string(recipe_id), Int.to_string(value)]) {
    Ok(_) ->
      case execute(pool, agg_sql, [Int.to_string(recipe_id)]) {
        Ok(_) -> Ok(())
        Error(e) -> Error(e)
      }
    Error(e) -> Error(e)
  }
}

// Helper to map a DB row into a Recipe record. Replace index-based column
// access with named access if your pog binding supports it.
fn row_to_recipe(row: Row) -> Result(Recipe, String) {
  case row_get_int(row, 1) {
    Error(e) -> Error(e)
    Ok(id) ->
      case row_get_string(row, 2) {
        Error(e) -> Error(e)
        Ok(title) ->
          case row_get_string(row, 3) {
            Error(e) -> Error(e)
            Ok(description) ->
              // For simplicity, we will not parse JSON ingredients/steps here.
              // The service layer can rehydrate them when needed.
              case row_get_jsonb(row, 4) {
                Error(e) -> Error(e)
                Ok(_ingredients_json) ->
                  case row_get_jsonb(row, 5) {
                    Error(e) -> Error(e)
                    Ok(_steps_json) ->
                      case row_get_string(row, 6) {
                        Error(e) -> Error(e)
                        Ok(meal_type) ->
                          case row_get_int(row, 7) {
                            Error(e) -> Error(e)
                            Ok(likes) ->
                              case row_get_int(row, 8) {
                                Error(e) -> Error(e)
                                Ok(dislikes) ->
                                  case row_get_jsonb(row, 9) {
                                    Error(e) -> Error(e)
                                    Ok(ai_meta) -> Ok(Recipe(id, title, description, [], [], meal_type, likes, dislikes, ai_meta))
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
  }
}
