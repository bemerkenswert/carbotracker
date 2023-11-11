import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import {
  ShellComponentActions,
  ShellRouterEffectsActions,
} from './shell.actions';
import { switchMap, from, map, catchError, of } from 'rxjs';
import { Router } from '@angular/router';

export const navigateToProducts$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ShellComponentActions.productsClicked),
      switchMap(() =>
        from(router.navigate(['app', 'products'])).pipe(
          map(() =>
            ShellRouterEffectsActions.navigationToProductsPageSuccessful(),
          ),
          catchError(() =>
            of(ShellRouterEffectsActions.navigationToProductsPageFailed()),
          ),
        ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const navigateToCurrentMeal$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ShellComponentActions.currentMealClicked),
      switchMap(() =>
        from(router.navigate(['app', 'current-meal'])).pipe(
          map(() =>
            ShellRouterEffectsActions.navigationToCurrentMealPageSuccessful(),
          ),
          catchError(() =>
            of(ShellRouterEffectsActions.navigationToCurrentMealPageFailed()),
          ),
        ),
      ),
    ),
  { dispatch: true, functional: true },
);
