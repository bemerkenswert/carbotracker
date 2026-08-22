import { EnvironmentProviders } from '@angular/core';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import {
  apiEffects,
  dialogEffects,
  routingEffects,
  snackbarEffects,
  sportsFeature,
} from './+state';

const provideSportsEffects = (): EnvironmentProviders =>
  provideEffects(apiEffects, dialogEffects, routingEffects, snackbarEffects);

const provideSportsState = (): EnvironmentProviders =>
  provideState(sportsFeature);

export const getSportsProviders = () => [
  provideSportsEffects(),
  provideSportsState(),
];
