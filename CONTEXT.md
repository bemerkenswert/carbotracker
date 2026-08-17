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
One of the four daily eating slots — breakfast, lunch, dinner, night — used as the unit for insulin-to-carb ratios.
_Avoid_: Meal (when meaning a slot, since "meal" already means CurrentMeal)

**Insulin-to-carb ratio**:
For a meal type, the user's ratio of insulin units per gram of carbs. Used to estimate a bolus dose for a current meal.
_Avoid_: Ratio, carb factor, insulin factor

**Saved meal**:
A named, immutable snapshot of a current meal's meal entries, stored by the user so it can be loaded back later (e.g. "Steffens Pasta Dream" = 250 g spaghetti, 60 g meat, 60 g bread).
_Avoid_: Recipe, saved-this-meal

## Pipeline

**Stalled run**:
A headless implement run that exits 0 without commits but leaves uncommitted work behind. The pipeline classifies it so the session gets exactly one resume instead of escalating and discarding recoverable work.
_Avoid_: Failure, restart

**Empty run**:
A headless implement run that exits 0 without commits and leaves a clean tree. Escalated immediately; its session is never resumed.
_Avoid_: Stalled run, failure

**Resume**:
Continuing the existing opencode session (via `--continue`) so the agent can finish and commit, reusing its context. A stalled run gets exactly one.
_Avoid_: Restart, retry

**Restart**:
Discarding the worktree and session and running fresh from scratch — the fallback when no resume can help, triggered by a human re-tagging the ticket.
_Avoid_: Resume, retry

**Review round**:
One analyze step (headless classify into a plan) plus one act step (apply the plan) of the review loop.
_Avoid_: Review pass, review cycle

**Watermark**:
The newest human review comment a PR's review loop has already handled.
_Avoid_: Last-seen, cursor

**Review trigger**:
What starts a review round: only human-authored comments and reviews; bot comments (GitHub Actions previews, dependabot) never trigger.
_Avoid_: Review signal (when it means a bot post)
