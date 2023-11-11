import { Routes } from '@angular/router';
import { ShellComponent } from './pages/Shell/shell.component';
import { provideEffects } from '@ngrx/effects';
import * as shellEffects from './shell.effects';

export const SHELL_ROUTES: Routes = [
  {
    path: '',
    component: ShellComponent,
    providers: [provideEffects(shellEffects)],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'products' },
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
    ],
  },
];
