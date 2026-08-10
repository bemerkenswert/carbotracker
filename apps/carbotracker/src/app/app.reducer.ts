import { createFeature, createReducer, on } from '@ngrx/store';
import { SettingsApiActions } from '../features/settings/+state/actions/api.actions';
import { InsulinToCarbRatiosPageActions } from '../features/settings/+state/actions/component.actions';

interface SettingsState {
  insulinToCarbRatios: {
    showInsulinUnits: boolean | null;
    breakfast: number | null;
    lunch: number | null;
    dinner: number | null;
    night: number | null;
  };
}

export const getInitialState = (): SettingsState => ({
  insulinToCarbRatios: {
    showInsulinUnits: null,
    breakfast: null,
    lunch: null,
    dinner: null,
    night: null,
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
