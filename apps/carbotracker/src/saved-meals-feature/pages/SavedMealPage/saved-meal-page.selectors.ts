import { createSelector } from '@ngrx/store';
import { settingsFeature } from '../../../app/app.reducer';
import { savedMealsFeature } from '../../+state/saved-meals.feature';

export const selectSavedMealPageViewModel = createSelector(
  savedMealsFeature.selectCurrentSavedMeal,
  settingsFeature.selectInsulinToCarbRatios,
  (savedMeal, insulinToCarbRatios) => {
    const sumOfSavedMealCarbs = savedMeal
      ? savedMeal.mealEntries
          .map((mealEntry) => mealEntry.amount * (mealEntry.carbs / 100))
          .reduce((acc, curr) => acc + curr, 0)
      : 0;

    return {
      savedMeal,
      sumOfSavedMealCarbs,
      showInsulinUnits: insulinToCarbRatios.showInsulinUnits,
      insulinUnits: {
        breakfast: insulinToCarbRatios.breakfast
          ? getInsulinUnits(sumOfSavedMealCarbs, insulinToCarbRatios.breakfast)
          : 0,
        lunch: insulinToCarbRatios.lunch
          ? getInsulinUnits(sumOfSavedMealCarbs, insulinToCarbRatios.lunch)
          : 0,
        dinner: insulinToCarbRatios.dinner
          ? getInsulinUnits(sumOfSavedMealCarbs, insulinToCarbRatios.dinner)
          : 0,
      },
    };
  },
);

const getInsulinUnits = (
  sumOfCarbs: number,
  insulinToCarbRatio: number,
): number => {
  return (sumOfCarbs / 10) * insulinToCarbRatio;
};
