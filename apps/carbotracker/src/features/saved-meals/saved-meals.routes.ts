import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import { apiEffects, dialogEffects, routingEffects } from './+state';
import { savedMealsFeature } from './+state';

const SAVED_MEALS_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./pages/saved-meals-page/saved-meals-page.component'),
    providers: [
      provideState(savedMealsFeature),
      provideEffects(apiEffects, dialogEffects, routingEffects),
    ],
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./pages/saved-meal-page/saved-meal-page.component'),
  },
];

export default SAVED_MEALS_ROUTES;
