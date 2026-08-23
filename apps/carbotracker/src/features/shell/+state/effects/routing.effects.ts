import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { mapResponse } from '@ngrx/operators';
import { from, switchMap } from 'rxjs';
import { ShellComponentActions } from '../actions/component.actions';
import { ShellRouterEffectsActions } from '../actions/routing.actions';

export const navigateToProducts$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ShellComponentActions.productsClicked),
      switchMap(() =>
        from(router.navigate(['app', 'products'])).pipe(
          mapResponse({
            next: () =>
              ShellRouterEffectsActions.navigationToProductsPageSuccessful(),
            error: (error) =>
              ShellRouterEffectsActions.navigationToProductsPageFailed({
                error,
              }),
          }),
        ),
      ),
    ),
  { functional: true },
);

export const navigateToSports$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ShellComponentActions.sportsClicked),
      switchMap(() =>
        from(router.navigate(['app', 'sports'])).pipe(
          mapResponse({
            next: () =>
              ShellRouterEffectsActions.navigationToSportsPageSuccessful(),
            error: (error) =>
              ShellRouterEffectsActions.navigationToSportsPageFailed({
                error,
              }),
          }),
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
          mapResponse({
            next: () =>
              ShellRouterEffectsActions.navigationToCurrentMealPageSuccessful(),
            error: (error) =>
              ShellRouterEffectsActions.navigationToCurrentMealPageFailed({
                error,
              }),
          }),
        ),
      ),
    ),
  { functional: true },
);

export const navigateToSavedMeals$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ShellComponentActions.savedMealsClicked),
      switchMap(() =>
        from(router.navigate(['app', 'saved-meals'])).pipe(
          mapResponse({
            next: () =>
              ShellRouterEffectsActions.navigationToSavedMealsPageSuccessful(),
            error: (error) =>
              ShellRouterEffectsActions.navigationToSavedMealsPageFailed({
                error,
              }),
          }),
        ),
      ),
    ),
  { functional: true },
);

export const navigateToHistory$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ShellComponentActions.historyClicked),
      switchMap(() =>
        from(router.navigate(['app', 'history'])).pipe(
          mapResponse({
            next: () =>
              ShellRouterEffectsActions.navigationToHistoryPageSuccessful(),
            error: (error) =>
              ShellRouterEffectsActions.navigationToHistoryPageFailed({
                error,
              }),
          }),
        ),
      ),
    ),
  { functional: true },
);

export const navigateToSettingsPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ShellComponentActions.settingsClicked),
      switchMap(() =>
        from(router.navigate(['app', 'settings'])).pipe(
          mapResponse({
            next: () =>
              ShellRouterEffectsActions.navigationToSettingsPageSuccessful(),
            error: (error) =>
              ShellRouterEffectsActions.navigationToSettingsPageFailed({
                error,
              }),
          }),
        ),
      ),
    ),
  { functional: true },
);
