import { createSelector } from '@ngrx/store';
import { savedMealsFeature } from '../../+state';

export const selectSavedMealPageViewModel = createSelector(
  savedMealsFeature.selectCurrentSavedMeal,
  (savedMeal) => ({ savedMeal }),
);
