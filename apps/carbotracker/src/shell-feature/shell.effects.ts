import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { catchError, from, map, of, switchMap } from 'rxjs';
import { PasswordApiActions } from '../features/auth/+state';
import {
  AccountPageActions,
  InsulinToCarbRatioPageActions,
} from '../features/settings/+state';
import {
  ShellComponentActions,
  ShellRouterEffectsActions,
} from './shell.actions';

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
  { functional: true },
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
  { functional: true },
);

export const navigateToSettingsPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(
        ShellComponentActions.settingsClicked,
        AccountPageActions.goBackIconClicked,
        PasswordApiActions.updatePasswordSuccessful,
        InsulinToCarbRatioPageActions.goBackIconClicked,
      ),
      switchMap(() =>
        from(router.navigate(['app', 'settings'])).pipe(
          map(() =>
            ShellRouterEffectsActions.navigationToSettingsPageSuccessful(),
          ),
          catchError(() =>
            of(ShellRouterEffectsActions.navigationToSettingsPageFailed()),
          ),
        ),
      ),
    ),
  { functional: true },
);
