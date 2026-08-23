import { createEntityAdapter, EntityState } from '@ngrx/entity';
import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { Sport } from '../sport.model';
import { SportsApiActions } from './actions/api.actions';
import { EditSportPageComponentActions } from './actions/component.actions';

interface SportsState {
  sports: EntityState<Sport>;
  selectedSport: string | null;
}

const sportsEntityAdapter = createEntityAdapter<Sport>();

export const getInitialState = (): SportsState => ({
  sports: sportsEntityAdapter.getInitialState(),
  selectedSport: null,
});

export const sportsFeature = createFeature({
  name: 'sports',
  reducer: createReducer(
    getInitialState(),
    on(
      EditSportPageComponentActions.selectedSportChanged,
      (state, { selectedSport }): SportsState => ({
        ...state,
        selectedSport,
      }),
    ),
    on(
      SportsApiActions.sportsCollectionChanged,
      (state, { sports }): SportsState => ({
        ...state,
        sports: sportsEntityAdapter.setAll(sports, state.sports),
      }),
    ),
  ),
  extraSelectors: ({ selectSports, selectSelectedSport }) => {
    const entitySelectors = sportsEntityAdapter.getSelectors(selectSports);
    const selectCurrentSport = createSelector(
      selectSelectedSport,
      entitySelectors.selectAll,
      (sportId, sports): Sport | null =>
        sports.find((sport) => sport.id === sportId) ?? null,
    );
    return {
      ...entitySelectors,
      selectCurrentSport,
    };
  },
});
