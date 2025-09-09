import { createSelector } from '@ngrx/store';
import { currentMealFeature } from '../../+state/current-meal.feature';
import { settingsFeature } from '../../../app/app.reducer';

export const selectSumOfCurrentMealCarbs = createSelector(
  currentMealFeature.selectAllMealEntries,
  (mealEntries) => {
    return mealEntries
      .map((mealEntry) => mealEntry.amount * (mealEntry.carbs / 100))
      .reduce((acc, curr) => acc + curr, 0);
  },
);

export const selectInsulinUnits = createSelector(
  settingsFeature.selectSettingsState,
  selectSumOfCurrentMealCarbs,
  ({ insulinToCarbRatios }, sumOfCurrentMealCarbs) => {
    const { breakfast, lunch, dinner } = insulinToCarbRatios;
    return {
      breakfast: breakfast
        ? getInsulinUnits(sumOfCurrentMealCarbs, breakfast)
        : 0,
      lunch: lunch ? getInsulinUnits(sumOfCurrentMealCarbs, lunch) : 0,
      dinner: dinner ? getInsulinUnits(sumOfCurrentMealCarbs, dinner) : 0,
    };
  },
);

export const selectShowInsulinUnits = createSelector(
  settingsFeature.selectInsulinToCarbRatios,
  ({ showInsulinUnits }) => showInsulinUnits,
);

const getInsulinUnits = (
  sumOfCarbs: number,
  insulinToCarbRatio: number,
): number => {
  return (sumOfCarbs / 10) * insulinToCarbRatio;
};

export const selectViewModel = createSelector(
  currentMealFeature.selectAllMealEntries,
  currentMealFeature.selectProductsAvailableToAdd,
  selectSumOfCurrentMealCarbs,
  selectShowInsulinUnits,
  selectInsulinUnits,
  (
    mealEntries,
    productsAvailable,
    sumOfCurrentMealCarbs,
    showInsulinUnits,
    insulinUnits,
  ) => ({
    mealEntries,
    productsAvailable,
    sumOfCurrentMealCarbs,
    showInsulinUnits,
    insulinUnits,
  }),
);
