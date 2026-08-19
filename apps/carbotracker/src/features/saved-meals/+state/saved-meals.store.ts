import { EntityState, createEntityAdapter } from '@ngrx/entity';
import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { SavedMeal } from '../saved-meal.model';
import { SavedMealsApiActions } from './actions/api.actions';
import {
  SavedMealPageComponentActions,
  SavedMealsPageComponentActions,
} from './actions/component.actions';

interface SavedMealsState {
  savedMeals: EntityState<SavedMeal>;
  selectedSavedMealId: string | null;
  nameFilter: string | null;
  error: string | null;
}

const savedMealsEntityAdapter = createEntityAdapter<SavedMeal>({
  sortComparer: (a, b) => a.name.localeCompare(b.name),
});

export const getInitialState = (): SavedMealsState => ({
  savedMeals: savedMealsEntityAdapter.getInitialState(),
  selectedSavedMealId: null,
  nameFilter: null,
  error: null,
});

export const savedMealsFeature = createFeature({
  name: 'savedMeals',
  reducer: createReducer(
    getInitialState(),
    on(
      SavedMealsPageComponentActions.nameFilterChanged,
      (state, { nameFilter }): SavedMealsState => ({
        ...state,
        nameFilter,
      }),
    ),
    on(
      SavedMealPageComponentActions.selectedSavedMealChanged,
      (state, { selectedSavedMealId }): SavedMealsState => ({
        ...state,
        selectedSavedMealId,
      }),
    ),
    on(
      SavedMealsApiActions.savedMealsCollectionChanged,
      (state, { savedMeals }): SavedMealsState => ({
        ...state,
        savedMeals: savedMealsEntityAdapter.setAll(
          savedMeals,
          state.savedMeals,
        ),
      }),
    ),
  ),
  extraSelectors: ({ selectSavedMeals, selectSelectedSavedMealId }) => {
    const entitySelectors =
      savedMealsEntityAdapter.getSelectors(selectSavedMeals);
    const selectCurrentSavedMeal = createSelector(
      selectSelectedSavedMealId,
      entitySelectors.selectEntities,
      (savedMealId, savedMeals): SavedMeal | null =>
        savedMealId ? (savedMeals[savedMealId] ?? null) : null,
    );
    return {
      ...entitySelectors,
      selectCurrentSavedMeal,
    };
  },
});
