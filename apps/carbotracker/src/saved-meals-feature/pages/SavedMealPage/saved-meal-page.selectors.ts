import { createSelector } from '@ngrx/store';
import { savedMealsFeature } from '../../+state/saved-meals.feature';

export const selectSavedMealPageViewModel = createSelector(
  savedMealsFeature.selectCurrentSavedMeal,
  (savedMeal) => ({ savedMeal }),
);
