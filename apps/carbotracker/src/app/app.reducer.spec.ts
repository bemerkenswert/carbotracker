import { getInitialState, settingsFeature } from './app.reducer';
import { InsulinToCarbRatiosPageActions } from '../features/settings/+state/actions/component.actions';

describe('settingsFeature', () => {
  it('defaults the night ratio to null', () => {
    const state = getInitialState();

    expect(state.insulinToCarbRatios.night).toBeNull();
  });

  it('stores the night ratio when the user saves the ratios', () => {
    const state = settingsFeature.reducer(
      getInitialState(),
      InsulinToCarbRatiosPageActions.saveChangesClicked({
        insulinToCarbRatios: {
          showInsulinUnits: true,
          breakfast: 1,
          lunch: 2,
          dinner: 3,
          night: 4,
        },
      }),
    );

    expect(state.insulinToCarbRatios.night).toBe(4);
  });
});
