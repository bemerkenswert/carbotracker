import { createSelector } from '@ngrx/store';
import { currentMealFeature } from '../../+state/current-meal.store';
import { settingsFeature } from '../../../settings/+state/settings.store';
import { estimateInsulin, sumOfMealEntryCarbs } from '../../current-meal.util';

export const selectSumOfCurrentMealCarbs = createSelector(
  currentMealFeature.selectAllMealEntries,
  (mealEntries) => sumOfMealEntryCarbs(mealEntries),
);

export const selectInsulinUnits = createSelector(
  settingsFeature.selectSettingsState,
  selectSumOfCurrentMealCarbs,
  ({ insulinToCarbRatios }, sumOfCurrentMealCarbs) => {
    const { breakfast, lunch, dinner, night } = insulinToCarbRatios;
    return {
      breakfast: breakfast
        ? estimateInsulin(sumOfCurrentMealCarbs, breakfast)
        : 0,
      lunch: lunch ? estimateInsulin(sumOfCurrentMealCarbs, lunch) : 0,
      dinner: dinner ? estimateInsulin(sumOfCurrentMealCarbs, dinner) : 0,
      night: night ? estimateInsulin(sumOfCurrentMealCarbs, night) : 0,
    };
  },
);

export const selectShowInsulinUnits = createSelector(
  settingsFeature.selectInsulinToCarbRatios,
  ({ showInsulinUnits }) => showInsulinUnits,
);

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
