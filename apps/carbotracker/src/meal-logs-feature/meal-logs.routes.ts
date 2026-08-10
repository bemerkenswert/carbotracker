import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import * as mealLogsEffects from './+state/meal-logs.effects';
import { mealLogsFeature } from './+state/meal-logs.feature';

const MEAL_LOGS_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () => import('./pages/HistoryPage/history-page.component'),
    providers: [provideState(mealLogsFeature), provideEffects(mealLogsEffects)],
  },
];

export default MEAL_LOGS_ROUTES;
