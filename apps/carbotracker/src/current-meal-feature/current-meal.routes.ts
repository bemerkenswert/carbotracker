import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import * as apiEffects from './+state/effects/api.effects';
import * as routingEffects from './+state/effects/routing.effects';
import { currentMealFeature } from './+state/current-meal.feature';

const CURRENT_MEAL_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./pages/CurrentMealPage/current-meal-page.component'),
    providers: [
      provideState(currentMealFeature),
      provideEffects(apiEffects, routingEffects),
    ],
  },
  {
    path: 'create',
    loadComponent: () =>
      import('./pages/CreateMealEntryPage/create-meal-entry-page.component'),
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./pages/EditMealEntryPage/edit-meal-entry-page.component'),
  },
];

export default CURRENT_MEAL_ROUTES;
