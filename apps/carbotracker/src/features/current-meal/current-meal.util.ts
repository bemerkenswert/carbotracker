import { MealEntry } from './current-meal.model';

/** Total carbohydrate mass (grams) across the meal's entries, weighted by
 *  each entry's carb density (carbs per 100 g) and amount in grams. */
export const sumOfMealEntryCarbs = (mealEntries: MealEntry[]): number =>
  mealEntries.reduce(
    (acc, mealEntry) => acc + mealEntry.amount * (mealEntry.carbs / 100),
    0,
  );

/** Estimated bolus insulin units for a meal's total carbs and a meal type's
 *  insulin-to-carb ratio. */
export const estimateInsulin = (
  sumOfCarbs: number,
  insulinToCarbRatio: number,
): number => (sumOfCarbs / 10) * insulinToCarbRatio;
