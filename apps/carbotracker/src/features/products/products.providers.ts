import { EnvironmentProviders } from '@angular/core';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import {
  apiEffects,
  dialogEffects,
  productsFeature,
  routingEffects,
  snackbarEffects,
} from './+state';

const provideProductsEffects = (): EnvironmentProviders =>
  provideEffects(apiEffects, dialogEffects, routingEffects, snackbarEffects);

const provideProductsState = (): EnvironmentProviders =>
  provideState(productsFeature);

export const getProductsProviders = () => [
  provideProductsEffects(),
  provideProductsState(),
];
