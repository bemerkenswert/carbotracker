import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { selectSumOfCurrentMealCarbs } from '../current-meal-feature/pages/CurrentMealPage/current-meal-page.selector';
import {
  InsulinToCarbRatiosPageActions,
  SettingsApiActions,
} from '../features/settings/+state';

interface AppSettingsState {
  insulinToCarbRatios: {
    showInsulinUnits: boolean;
    breakfast: number | null;
    lunch: number | null;
    dinner: number | null;
  };
}

export const getInitialState = (): AppSettingsState => ({
  insulinToCarbRatios: {
    showInsulinUnits: false,
    breakfast: null,
    lunch: null,
    dinner: null,
  },
});

export const appSettingsFeature = createFeature({
  name: 'appSettings',
  reducer: createReducer(
    getInitialState(),
    on(
      InsulinToCarbRatiosPageActions.saveChangesClicked,
      SettingsApiActions.insulinToCarbRatiosCollectionChanged,
      (state, { insulinToCarbRatios }): AppSettingsState => {
        return {
          ...state,
          insulinToCarbRatios,
        };
      },
    ),
  ),
  extraSelectors(baseSelectors) {
    const selectInsulinUnits = createSelector(
      baseSelectors.selectAppSettingsState,
      selectSumOfCurrentMealCarbs,
      ({ insulinToCarbRatios }, sumOfCurrentMealCarbs) => {
        const { breakfast, lunch, dinner } = insulinToCarbRatios;
        if (sumOfCurrentMealCarbs > 0) {
          return {
            breakfastInsulinUnits: breakfast
              ? getInsulinUnits(sumOfCurrentMealCarbs, breakfast)
              : null,
            lunchInsulinUnits: lunch
              ? getInsulinUnits(sumOfCurrentMealCarbs, lunch)
              : null,
            dinnerInsulinUnits: dinner
              ? getInsulinUnits(sumOfCurrentMealCarbs, dinner)
              : null,
          };
        } else {
          return null;
        }
      },
    );
    const selectShowInsulinUnits = createSelector(
      baseSelectors.selectInsulinToCarbRatios,
      ({ showInsulinUnits }) => showInsulinUnits,
    );
    return {
      ...baseSelectors,
      selectInsulinUnits,
      selectShowInsulinUnits,
    };
  },
});

const getInsulinUnits = (
  sumOfCarbs: number,
  insulinToCarbRatio: number,
): number => {
  return (sumOfCarbs / 10) * insulinToCarbRatio;
};
