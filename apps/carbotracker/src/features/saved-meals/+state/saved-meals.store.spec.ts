import { SavedMeal } from '../saved-meal.model';
import { SavedMealsApiActions } from './actions/api.actions';
import {
  SavedMealPageComponentActions,
  SavedMealsPageComponentActions,
} from './actions/component.actions';
import { getInitialState, savedMealsFeature } from './saved-meals.store';

describe('savedMealsFeature', () => {
  const createSavedMeal = (
    id: string,
    name: string,
    createdAt: Date,
  ): SavedMeal => ({ id, name, createdAt, mealEntries: [] });

  const older = createSavedMeal('a', 'older', new Date('2024-01-01'));
  const newer = createSavedMeal('b', 'newer', new Date('2024-06-01'));

  it('returns the initial state for an unknown action', () => {
    const initialState = getInitialState();
    const action = { type: 'Unknown' };

    const state = savedMealsFeature.reducer(initialState, action);

    expect(state).toBe(initialState);
  });

  it('stores the name filter when it changes', () => {
    const state = savedMealsFeature.reducer(
      getInitialState(),
      SavedMealsPageComponentActions.nameFilterChanged({ nameFilter: 'pasta' }),
    );

    const nameFilter = savedMealsFeature.selectNameFilter.projector(state);

    expect(nameFilter).toBe('pasta');
  });

  it('clears the name filter when the filter is cleared', () => {
    const state = savedMealsFeature.reducer(
      getInitialState(),
      SavedMealsPageComponentActions.nameFilterChanged({ nameFilter: null }),
    );

    const nameFilter = savedMealsFeature.selectNameFilter.projector(state);

    expect(nameFilter).toBeNull();
  });

  it('exposes saved meals sorted by name when the collection changes', () => {
    const state = savedMealsFeature.reducer(
      getInitialState(),
      SavedMealsApiActions.savedMealsCollectionChanged({
        savedMeals: [older, newer],
      }),
    );
    const savedMeals = savedMealsFeature.selectSavedMeals.projector(state);
    const result = savedMealsFeature.selectAll.projector(savedMeals);
    expect(result).toEqual([newer, older]);
  });

  it('exposes the selected saved meal', () => {
    let state = savedMealsFeature.reducer(
      getInitialState(),
      SavedMealsApiActions.savedMealsCollectionChanged({
        savedMeals: [older, newer],
      }),
    );
    state = savedMealsFeature.reducer(
      state,
      SavedMealPageComponentActions.selectedSavedMealChanged({
        selectedSavedMealId: 'a',
      }),
    );
    const selectedSavedMealId =
      savedMealsFeature.selectSelectedSavedMealId.projector(state);
    const entities = savedMealsFeature.selectEntities.projector(
      savedMealsFeature.selectSavedMeals.projector(state),
    );
    const result = savedMealsFeature.selectCurrentSavedMeal.projector(
      selectedSavedMealId,
      entities,
    );
    expect(result).toEqual(older);
  });

  it('returns null selected meal when no id is selected', () => {
    const state = getInitialState();
    const selectedSavedMealId =
      savedMealsFeature.selectSelectedSavedMealId.projector(state);
    const entities = savedMealsFeature.selectEntities.projector(
      savedMealsFeature.selectSavedMeals.projector(state),
    );
    const result = savedMealsFeature.selectCurrentSavedMeal.projector(
      selectedSavedMealId,
      entities,
    );
    expect(result).toBeNull();
  });

  it('starts with an empty saved meals list', () => {
    const savedMeals =
      savedMealsFeature.selectSavedMeals.projector(getInitialState());
    const result = savedMealsFeature.selectAll.projector(savedMeals);
    expect(result).toEqual([]);
  });
});
