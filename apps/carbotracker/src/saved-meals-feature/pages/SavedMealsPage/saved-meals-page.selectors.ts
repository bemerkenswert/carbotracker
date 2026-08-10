import { createSelector } from '@ngrx/store';
import { savedMealsFeature } from '../../+state/saved-meals.feature';
import { SavedMeal } from '../../saved-meal.model';

export const selectSavedMealsViewModel = createSelector(
  savedMealsFeature.selectAll,
  (savedMeals) => ({
    savedMeals: savedMeals.map(toSavedMealListItem),
  }),
);

const toSavedMealListItem = (savedMeal: SavedMeal) => ({
  savedMeal,
  totalCarbs: savedMeal.mealEntries.reduce(
    (sum, mealEntry) => sum + mealEntry.amount * (mealEntry.carbs / 100),
    0,
  ),
});
