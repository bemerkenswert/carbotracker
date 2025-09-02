import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { selectSumOfCurrentMealCarbs } from 'apps/carbotracker/src/current-meal-feature/pages/CurrentMealPage/current-meal-page.selector';
import { FactorsPageActions } from './actions/component.actions';

interface FactorsState {
  showInjectionUnits: boolean;
  breakfastFactor: number | null;
  lunchFactor: number | null;
  dinnerFactor: number | null;
}

export const getInitialState = (): FactorsState => ({
  showInjectionUnits: false,
  breakfastFactor: null,
  lunchFactor: null,
  dinnerFactor: null,
});

export const factorsFeature = createFeature({
  name: 'factors',
  reducer: createReducer(
    getInitialState(),
    on(
      FactorsPageActions.saveChangesClicked,
      (
        state,
        { showInjectionUnits, breakfastFactor, lunchFactor, dinnerFactor },
      ): FactorsState => ({
        ...state,
        showInjectionUnits,
        breakfastFactor,
        lunchFactor,
        dinnerFactor,
      }),
    ),
  ),
  extraSelectors(baseSelectors) {
    const selectInjectionUnits = createSelector(
      baseSelectors.selectFactorsState,
      selectSumOfCurrentMealCarbs,
      (
        { breakfastFactor, lunchFactor, dinnerFactor },
        sumOfCurrentMealCarbs,
      ) => {
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
    return { ...baseSelectors, selectInjectionUnits };
  },
});

const getInjectionUnits = (sumOfCarbs: number, factor: number): number => {
  return (sumOfCarbs / 10) * factor;
};
