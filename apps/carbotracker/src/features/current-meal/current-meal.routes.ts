import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import { apiEffects, routingEffects, snackbarEffects } from './+state';
import { currentMealFeature } from './+state';

const CURRENT_MEAL_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./pages/current-meal-page/current-meal-page.component'),
    providers: [
      provideState(currentMealFeature),
      provideEffects(apiEffects, routingEffects, snackbarEffects),
    ],
  },
  {
    path: 'create',
    loadComponent: () =>
      import('./pages/create-meal-entry-page/create-meal-entry-page.component'),
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./pages/edit-meal-entry-page/edit-meal-entry-page.component'),
  },
];

export default CURRENT_MEAL_ROUTES;
