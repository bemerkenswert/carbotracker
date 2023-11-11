import { Routes } from '@angular/router';
import { CurrentMealPageComponent } from './pages/CurrentMealPage/current-meal-page.component';
import { provideState } from '@ngrx/store';
import { currentMealFeature } from './+state/current-meal.feature';
import * as currentMealEffects from './+state/current-meal.effects';
import { provideEffects } from '@ngrx/effects';

export const CURRENT_MEAL_ROUTES: Routes = [
  {
    path: '',
    component: CurrentMealPageComponent,
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
