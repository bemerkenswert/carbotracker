import { createSelector } from '@ngrx/store';
import { currentMealFeature } from '../../+state/current-meal.feature';

export const selectSumOfCurrentMealCarbs = createSelector(
  currentMealFeature.selectAllMealEntries,
  (mealEntries) => {
    return mealEntries
      .map((mealEntry) => mealEntry.amount * (mealEntry.carbs / 100))
      .reduce((acc, curr) => acc + curr, 0);
  },
);
