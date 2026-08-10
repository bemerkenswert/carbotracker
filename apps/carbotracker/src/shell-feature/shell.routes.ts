import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { ShellComponent } from './pages/Shell/shell.component';
import * as shellEffects from './shell.effects';

const SHELL_ROUTES: Routes = [
  {
    path: '',
    component: ShellComponent,
    providers: [provideEffects(shellEffects)],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'current-meal' },
      {
        path: 'products',
        loadChildren: () => import('../products-feature/products.routes'),
      },
      {
        path: 'current-meal',
        loadChildren: () =>
          import('../current-meal-feature/current-meal.routes'),
      },
      {
        path: 'saved-meals',
        loadChildren: () => import('../saved-meals-feature/saved-meals.routes'),
      },
      {
        path: 'history',
        loadChildren: () => import('../meal-logs-feature/meal-logs.routes'),
      },
      {
        path: 'settings',
        loadChildren: () => import('../features/settings/settings.routes'),
      },
    ],
  },
];

export default SHELL_ROUTES;
