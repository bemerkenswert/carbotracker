import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { selectSumOfCurrentMealCarbs } from '../current-meal-feature/pages/CurrentMealPage/current-meal-page.selector';
import {
  InsulinToCarbRatiosPageActions,
  SettingsApiActions,
} from '../features/settings/+state';

interface AppSettingsState {
  insulinToCarbRatios: {
    showInsulinUnits: boolean;
    breakfastInsulinToCarbRatio: number | null;
    lunchInsulinToCarbRatio: number | null;
    dinnerInsulinToCarbRatio: number | null;
  };
}

export const getInitialState = (): AppSettingsState => ({
  insulinToCarbRatios: {
    showInsulinUnits: false,
    breakfastInsulinToCarbRatio: null,
    lunchInsulinToCarbRatio: null,
    dinnerInsulinToCarbRatio: null,
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
        const {
          breakfastInsulinToCarbRatio,
          lunchInsulinToCarbRatio,
          dinnerInsulinToCarbRatio,
        } = insulinToCarbRatios;
        if (sumOfCurrentMealCarbs > 0) {
          return {
            breakfastInsulinUnits: breakfastInsulinToCarbRatio
              ? getInsulinUnits(
                  sumOfCurrentMealCarbs,
                  breakfastInsulinToCarbRatio,
                )
              : null,
            lunchInsulinUnits: lunchInsulinToCarbRatio
              ? getInsulinUnits(sumOfCurrentMealCarbs, lunchInsulinToCarbRatio)
              : null,
            dinnerInsulinUnits: dinnerInsulinToCarbRatio
              ? getInsulinUnits(sumOfCurrentMealCarbs, dinnerInsulinToCarbRatio)
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
