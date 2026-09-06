// src/slices/recipes/models.gleam
// Typed domain records for the recipes slice.

pub type MealType = Lunch | Dinner

pub type Ingredient {
  Ingredient(name: String, quantity: String)
}

pub type Recipe {
  Recipe(
    id: Int,
    title: String,
    description: String,
    ingredients: List(Ingredient),
    steps: List(String),
    meal_type: MealType,
    likes: Int,
    dislikes: Int,
    ai_meta: String
  )
}
