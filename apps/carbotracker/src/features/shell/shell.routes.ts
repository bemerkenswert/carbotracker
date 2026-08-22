import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { routingEffects } from './+state';
import { ShellComponent } from './pages/shell/shell.component';

const SHELL_ROUTES: Routes = [
  {
    path: '',
    component: ShellComponent,
    providers: [provideEffects(routingEffects)],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'current-meal' },
      {
        path: 'products',
        loadChildren: () => import('../products/products.routes'),
      },
      {
        path: 'sports',
        loadChildren: () => import('../sports/sports.routes'),
      },
      {
        path: 'current-meal',
        loadChildren: () => import('../current-meal/current-meal.routes'),
      },
      {
        path: 'saved-meals',
        loadChildren: () => import('../saved-meals/saved-meals.routes'),
      },
      {
        path: 'history',
        loadChildren: () => import('../../meal-logs-feature/meal-logs.routes'),
      },
      {
        path: 'settings',
        loadChildren: () => import('../settings/settings.routes'),
      },
    ],
  },
];

export default SHELL_ROUTES;
