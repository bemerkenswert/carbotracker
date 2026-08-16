import { createSelector } from '@ngrx/store';
import { currentMealFeature } from '../../+state/current-meal.store';
import { settingsFeature } from '../../../settings/+state/settings.store';

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
    const { breakfast, lunch, dinner, night } = insulinToCarbRatios;
    return {
      breakfast: breakfast
        ? getInsulinUnits(sumOfCurrentMealCarbs, breakfast)
        : 0,
      lunch: lunch ? getInsulinUnits(sumOfCurrentMealCarbs, lunch) : 0,
      dinner: dinner ? getInsulinUnits(sumOfCurrentMealCarbs, dinner) : 0,
      night: night ? getInsulinUnits(sumOfCurrentMealCarbs, night) : 0,
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
  currentMealFeature.selectCurrentMealIsEmpty,
  selectSumOfCurrentMealCarbs,
  selectShowInsulinUnits,
  selectInsulinUnits,
  (
    mealEntries,
    productsAvailable,
    currentMealIsEmpty,
    sumOfCurrentMealCarbs,
    showInsulinUnits,
    insulinUnits,
  ) => ({
    mealEntries,
    productsAvailable,
    currentMealIsEmpty,
    sumOfCurrentMealCarbs,
    showInsulinUnits,
    insulinUnits,
  }),
);
