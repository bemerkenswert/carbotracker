import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { selectSumOfCurrentMealCarbs } from '../current-meal-feature/pages/CurrentMealPage/current-meal-page.selector';
import {
  FactorsPageActions,
  SettingsApiActions,
} from '../features/settings/+state';

interface AppSettingsState {
  factors: {
    showInjectionUnits: boolean;
    breakfastFactor: number | null;
    lunchFactor: number | null;
    dinnerFactor: number | null;
  };
}

export const getInitialState = (): AppSettingsState => ({
  factors: {
    showInjectionUnits: false,
    breakfastFactor: null,
    lunchFactor: null,
    dinnerFactor: null,
  },
});

export const appSettingsFeature = createFeature({
  name: 'appSettings',
  reducer: createReducer(
    getInitialState(),
    on(
      FactorsPageActions.saveChangesClicked,
      SettingsApiActions.factorsCollectionChanged,
      (state, { factors }): AppSettingsState => {
        console.warn(factors);
        return {
          ...state,
          factors,
        };
      },
    ),
  ),
  extraSelectors(baseSelectors) {
    const selectInjectionUnits = createSelector(
      baseSelectors.selectAppSettingsState,
      selectSumOfCurrentMealCarbs,
      ({ factors }, sumOfCurrentMealCarbs) => {
        const { breakfastFactor, lunchFactor, dinnerFactor } = factors;
        if (sumOfCurrentMealCarbs > 0) {
          return {
            breakfastInjectionUnit: breakfastFactor
              ? getInjectionUnits(sumOfCurrentMealCarbs, breakfastFactor)
              : null,
            lunchInjectionUnit: lunchFactor
              ? getInjectionUnits(sumOfCurrentMealCarbs, lunchFactor)
              : null,
            dinnerInjectionUnit: dinnerFactor
              ? getInjectionUnits(sumOfCurrentMealCarbs, dinnerFactor)
              : null,
          };
        } else {
          return null;
        }
      },
    );
    const selectShowInjectionUnits = createSelector(
      baseSelectors.selectFactors,
      ({ showInjectionUnits }) => showInjectionUnits,
    );
    return { ...baseSelectors, selectInjectionUnits, selectShowInjectionUnits };
  },
});

const getInjectionUnits = (sumOfCarbs: number, factor: number): number => {
  return (sumOfCarbs / 10) * factor;
};
