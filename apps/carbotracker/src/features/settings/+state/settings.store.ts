import { createFeature, createReducer, on } from '@ngrx/store';
import { ThemePreference } from '../theme-preference.model';
import { SettingsApiActions } from './actions/api.actions';
import {
  InsulinToCarbRatiosPageActions,
  SettingsPageActions,
} from './actions/component.actions';

interface SettingsState {
  insulinToCarbRatios: {
    showInsulinUnits: boolean | null;
    breakfast: number | null;
    lunch: number | null;
    dinner: number | null;
    night: number | null;
  };
  themePreference: ThemePreference;
}

export const getInitialState = (): SettingsState => ({
  insulinToCarbRatios: {
    showInsulinUnits: null,
    breakfast: null,
    lunch: null,
    dinner: null,
    night: null,
  },
  themePreference: 'system',
});

export const settingsFeature = createFeature({
  name: 'settings',
  reducer: createReducer(
    getInitialState(),
    on(
      InsulinToCarbRatiosPageActions.saveChangesClicked,
      SettingsApiActions.insulinToCarbRatiosCollectionChanged,
      (state, { insulinToCarbRatios }): SettingsState => {
        return {
          ...state,
          insulinToCarbRatios,
        };
      },
    ),
    on(
      SettingsPageActions.themeChanged,
      SettingsApiActions.themeCollectionChanged,
      (state, { themePreference }): SettingsState => {
        return {
          ...state,
          themePreference,
        };
      },
    ),
  ),
});
