import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import * as currentMealEffects from './+state/current-meal.effects';
import { currentMealFeature } from './+state/current-meal.feature';

export const CURRENT_MEAL_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./pages/CurrentMealPage/current-meal-page.component'),
    providers: [
      provideState(currentMealFeature),
      provideEffects(currentMealEffects),
    ],
  },
  {
    path: 'create',
    loadComponent: () =>
      import('./pages/CreateMealEntryPage/create-meal-entry-page.component'),
  },
];
