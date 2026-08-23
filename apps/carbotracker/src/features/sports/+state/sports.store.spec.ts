import { Sport } from '../sport.model';
import { SportsApiActions } from './actions/api.actions';
import { EditSportPageComponentActions } from './actions/component.actions';
import { getInitialState, sportsFeature } from './sports.store';

describe('sportsFeature', () => {
  const createSport = (id: string, name: string, creator: string): Sport => ({
    id,
    name,
    creator,
  });

  const cycling = createSport('s1', 'cycling', 'user-a');
  const running = createSport('s2', 'running', 'user-b');

  it('returns the initial state for an unknown action', () => {
    const initialState = getInitialState();
    const action = { type: 'Unknown' };

    const state = sportsFeature.reducer(initialState, action);

    expect(state).toBe(initialState);
  });

  it('sets the selected sport when the selected sport changes', () => {
    const state = sportsFeature.reducer(
      getInitialState(),
      EditSportPageComponentActions.selectedSportChanged({
        selectedSport: 's1',
      }),
    );

    const selectedSport = sportsFeature.selectSelectedSport.projector(state);

    expect(selectedSport).toBe('s1');
  });

  it('stores the collection of sports when the collection changes', () => {
    const state = sportsFeature.reducer(
      getInitialState(),
      SportsApiActions.sportsCollectionChanged({
        sports: [cycling, running],
      }),
    );

    const selectedSports = sportsFeature.selectSports.projector(state);
    const sports = sportsFeature.selectAll.projector(selectedSports);

    expect(sports).toEqual([cycling, running]);
  });

  it('exposes the current sport from the selected id', () => {
    let state = sportsFeature.reducer(
      getInitialState(),
      SportsApiActions.sportsCollectionChanged({
        sports: [cycling, running],
      }),
    );
    state = sportsFeature.reducer(
      state,
      EditSportPageComponentActions.selectedSportChanged({
        selectedSport: 's1',
      }),
    );
    const selectedSport = sportsFeature.selectSelectedSport.projector(state);
    const sports = sportsFeature.selectAll.projector(
      sportsFeature.selectSports.projector(state),
    );

    const currentSport = sportsFeature.selectCurrentSport.projector(
      selectedSport,
      sports,
    );

    expect(currentSport).toEqual(cycling);
  });

  it('exposes null current sport when there is no selected sport', () => {
    const state = getInitialState();
    const selectedSport = sportsFeature.selectSelectedSport.projector(state);
    const sports = sportsFeature.selectAll.projector(
      sportsFeature.selectSports.projector(state),
    );

    const currentSport = sportsFeature.selectCurrentSport.projector(
      selectedSport,
      sports,
    );

    expect(currentSport).toBeNull();
  });
});
