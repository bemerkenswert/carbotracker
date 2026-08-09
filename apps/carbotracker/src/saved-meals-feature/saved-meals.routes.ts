import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import * as savedMealsEffects from './+state/saved-meals.effects';
import { savedMealsFeature } from './+state/saved-meals.feature';

const SAVED_MEALS_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./pages/SavedMealsPage/saved-meals-page.component'),
    providers: [
      provideState(savedMealsFeature),
      provideEffects(savedMealsEffects),
    ],
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./pages/SavedMealPage/saved-meal-page.component'),
  },
];

export default SAVED_MEALS_ROUTES;
