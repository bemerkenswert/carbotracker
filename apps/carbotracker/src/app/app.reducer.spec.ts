import { getInitialState, settingsFeature } from './app.reducer';
import { SettingsApiActions } from '../features/settings/+state/actions/api.actions';
import {
  InsulinToCarbRatiosPageActions,
  SettingsPageActions,
} from '../features/settings/+state/actions/component.actions';

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

  it('defaults the theme preference to system', () => {
    const state = getInitialState();

    expect(state.themePreference).toBe('system');
  });

  it('stores the theme preference when the user changes the theme', () => {
    const state = settingsFeature.reducer(
      getInitialState(),
      SettingsPageActions.themeChanged({ themePreference: 'dark' }),
    );

    expect(state.themePreference).toBe('dark');
  });

  it('stores the theme preference when the theme collection changes', () => {
    const state = settingsFeature.reducer(
      getInitialState(),
      SettingsApiActions.themeCollectionChanged({ themePreference: 'light' }),
    );

    expect(state.themePreference).toBe('light');
  });

  it('exposes a selector for the resolved theme preference', () => {
    const state = settingsFeature.reducer(
      getInitialState(),
      SettingsPageActions.themeChanged({ themePreference: 'dark' }),
    );

    expect(settingsFeature.selectThemePreference.projector(state)).toBe('dark');
  });
});
