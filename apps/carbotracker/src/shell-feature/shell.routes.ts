import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { ShellComponent } from './pages/Shell/shell.component';
import * as shellEffects from './shell.effects';

export const SHELL_ROUTES: Routes = [
  {
    path: '',
    component: ShellComponent,
    providers: [provideEffects(shellEffects)],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'current-meal' },
      {
        path: 'products',
        loadChildren: () =>
          import('../products-feature/products.routes').then(
            (m) => m.PRODUCTS_ROUTES,
          ),
      },
      {
        path: 'current-meal',
        loadChildren: () =>
          import('../current-meal-feature/current-meal.routes').then(
            (m) => m.CURRENT_MEAL_ROUTES,
          ),
      },
      {
        path: 'settings',
        loadChildren: () =>
          import('../settings-feature/settings.routes').then(
            (m) => m.SETTINGS_ROUTES,
          ),
      },
    ],
  },
];
