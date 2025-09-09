import { createFeature, createReducer, on } from '@ngrx/store';
import {
  InsulinToCarbRatiosPageActions,
  SettingsApiActions,
} from '../features/settings/+state';

interface SettingsState {
  insulinToCarbRatios: {
    showInsulinUnits: boolean | null;
    breakfast: number | null;
    lunch: number | null;
    dinner: number | null;
  };
}

export const getInitialState = (): SettingsState => ({
  insulinToCarbRatios: {
    showInsulinUnits: null,
    breakfast: null,
    lunch: null,
    dinner: null,
  },
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
  ),
});
