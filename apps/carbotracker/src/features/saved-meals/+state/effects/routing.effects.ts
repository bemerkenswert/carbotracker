import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { mapResponse } from '@ngrx/operators';
import { exhaustMap, from } from 'rxjs';
import { SavedMealsApiActions } from '../actions/api.actions';
import { SavedMealsPageComponentActions } from '../actions/component.actions';
import { SavedMealsRouterEffectsActions } from '../actions/routing.actions';

export const navigateToSavedMeal$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SavedMealsPageComponentActions.savedMealClicked),
      exhaustMap(({ savedMeal }) =>
        from(router.navigate(['app', 'saved-meals', savedMeal.id])).pipe(
          mapResponse({
            next: () =>
              SavedMealsRouterEffectsActions.navigationToSavedMealPageSuccessful(),
            error: (error) =>
              SavedMealsRouterEffectsActions.navigationToSavedMealPageFailed({
                error,
              }),
          }),
        ),
      ),
    ),
  { functional: true },
);

export const navigateToSavedMealsPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SavedMealsApiActions.deletingSavedMealSuccessful),
      exhaustMap(() =>
        from(router.navigate(['app', 'saved-meals'])).pipe(
          mapResponse({
            next: () =>
              SavedMealsRouterEffectsActions.navigationToSavedMealsPageSuccessful(),
            error: (error) =>
              SavedMealsRouterEffectsActions.navigationToSavedMealsPageFailed({
                error,
              }),
          }),
        ),
      ),
    ),
  { functional: true },
);
