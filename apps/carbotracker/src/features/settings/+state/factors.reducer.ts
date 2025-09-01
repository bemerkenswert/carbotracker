import { createFeature, createReducer, on } from "@ngrx/store";
import { FactorsPageActions } from "./actions/component.actions";

interface FactorsState {
    showInjectionUnits: boolean | null;
    breakfastFactor: number | null;
    lunchFactor: number | null;
    dinnerFactor: number | null;
}

export const getInitialState = (): FactorsState => ({
    showInjectionUnits: null,
    breakfastFactor: null,
    lunchFactor: null,
    dinnerFactor: null
});

export const factorsFeature = createFeature({
    name: 'factors',
    reducer: createReducer(
        getInitialState(),
        on(
            FactorsPageActions.saveChangesClicked,
            (state, { showInjectionUnits, breakfastFactor, lunchFactor, dinnerFactor }): FactorsState => ({
                ...state,
                showInjectionUnits,
                breakfastFactor,
                lunchFactor,
                dinnerFactor
            }),
        ),
    ),
});
