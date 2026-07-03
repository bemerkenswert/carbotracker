import { Routes } from '@angular/router';

const SAVED_MEALS_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./pages/SavedMealsPage/saved-meals-page.component'),
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./pages/SavedMealPage/saved-meal-page.component'),
  },
];

export default SAVED_MEALS_ROUTES;
