import { EnvironmentProviders } from '@angular/core';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import {
  apiEffects,
  authFeature,
  routingEffects,
  snackbarEffects,
} from './+state';

const provideAuthEffects = (): EnvironmentProviders =>
  provideEffects(apiEffects, routingEffects, snackbarEffects);

const provideAuthState = (): EnvironmentProviders => provideState(authFeature);

export const getAuthProviders = () => [
  provideAuthEffects(),
  provideAuthState(),
];
