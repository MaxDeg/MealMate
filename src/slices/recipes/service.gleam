// src/slices/recipes/service.gleam
// Business logic for the recipes slice. Uses AiClient and infra.db.

import ai.client_behaviour.{AiClient, GenerateParams, AiRecipe, Ingredient as AiIngredient, MealType}
import infra.db.{Pool, with_transaction}
import slices.recipes.db.{insert_recipe}
import slices.recipes.models.{Recipe, Ingredient}
import infra.otel.{with_span}

fn ai_ing_to_domain(ai: AiIngredient) -> Ingredient {
  Ingredient(ai.name, ai.quantity)
}

fn meal_type_to_string(mt: MealType) -> String {
  case mt { Lunch -> "lunch" ; Dinner -> "dinner" }
}

// Very small JSON serializer for ai.meta map used for persistence.
// Replace with a real JSON library in production.
fn meta_map_to_json(meta: Map(String, String)) -> String {
  meta
  |> Map.to_list
  |> List.map(fn({k,v}) { "\"" ++ k ++ "\":\"" ++ v ++ "\"" })
  |> String.join(",")
  |> fn(s) { "{" ++ s ++ "}" }
}

pub fn generate_and_save(
  pool: Pool,
  ai: AiClient,
  user_id: Int,
  meal_type: MealType,
  include: List(String),
  exclude: List(String),
) -> Result(Recipe, String) {
  with_span("recipes.generate_and_save", fn() {
    let params = GenerateParams(meal_type, include, exclude, "{}")
    case ai.generate(params) {
      Ok(ai_recipe) ->
        // Validate
        if List.length(ai_recipe.ingredients) == 0 { Error("AI returned no ingredients") } else if List.length(ai_recipe.steps) == 0 { Error("AI returned no steps") } else {
          let ingredients = ai_recipe.ingredients |> List.map(ai_ing_to_domain)
          let steps = ai_recipe.steps
          // Serialize ai meta
          let ai_meta_json = meta_map_to_json(ai_recipe.meta)
          // Persist in transaction and return typed Recipe
          case with_transaction(pool, fn(conn) {
            // insert_recipe uses pool/conn internally; pass pool for now
            insert_recipe(pool, ai_recipe.title, ai_recipe.description, ingredients, steps, meal_type_to_string(meal_type), ai_meta_json)
          }) {
            Ok(recipe) -> Ok(recipe)
            Error(e) -> Error(e)
          }
        }
      Error(e) -> Error(e)
    }
  })
}
