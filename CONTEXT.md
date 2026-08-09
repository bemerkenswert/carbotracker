# Carbotracker

A food-tracking app for people with diabetes. The user logs in, maintains a personal catalog of foods, assembles a running meal by adding foods in gram amounts, and can optionally see an estimated bolus insulin dose for each daily meal based on their insulin-to-carb ratios.

## Language

**Product**:
A food item the user defines in their own catalog. Carries `carbs` as the carbohydrate density, i.e. carbs per 100 g of the food.
_Avoid_: Food item, ingredient, food entry

**Carbs (density)**:
The carbohydrate content of a Product expressed per 100 g.
_Avoid_: Carbohydrates (when it means density), carb count in absolute terms

**MealEntry**:
One Product plus an amount in grams, placed into the current meal. Snapshot of the Product's name and carbs at the time it was added.
_Avoid_: Meal item, food entry, entry

**CurrentMeal**:
The meal being assembled right now. A list of meal entries; one per user.
_Avoid_: Active meal, working meal

**Meal type**:
One of the three daily eating slots — breakfast, lunch, dinner — used as the unit for insulin-to-carb ratios.
_Avoid_: Meal (when meaning a slot, since "meal" already means CurrentMeal)

**Insulin-to-carb ratio**:
For a meal type, the user's ratio of insulin units per gram of carbs. Used to estimate a bolus dose for a current meal.
_Avoid_: Ratio, carb factor, insulin factor

**Saved meal**:
A named, immutable snapshot of a current meal's meal entries, stored by the user so it can be loaded back later (e.g. "Steffens Pasta Dream" = 250 g spaghetti, 60 g meat, 60 g bread).
_Avoid_: Recipe, saved-this-meal
