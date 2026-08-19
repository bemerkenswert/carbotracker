import { EnvironmentProviders } from '@angular/core';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import {
  apiEffects,
  routingEffects,
  settingsFeature,
  snackbarEffects,
} from './+state';

const provideSettingsEffects = (): EnvironmentProviders =>
  provideEffects(apiEffects, routingEffects, snackbarEffects);

const provideSettingsState = (): EnvironmentProviders =>
  provideState(settingsFeature);

export const getSettingsProviders = () => [
  provideSettingsEffects(),
  provideSettingsState(),
];
