import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { mapResponse } from '@ngrx/operators';
import { from, switchMap } from 'rxjs';
import { CurrentMealApiActions } from '../actions/api.actions';
import {
  CurrentMealPageComponentActions,
  EditMealEntryPageComponentActions,
} from '../actions/component.actions';
import { CurrentMealRouterEffectsActions } from '../actions/routing.actions';

export const navigateToCreateMealEntry$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(CurrentMealPageComponentActions.addClicked),
      switchMap(() =>
        from(router.navigate(['app', 'current-meal', 'create'])).pipe(
          mapResponse({
            next: () =>
              CurrentMealRouterEffectsActions.navigationToCreateMealEntryPageSuccessful(),
            error: (error) =>
              CurrentMealRouterEffectsActions.navigationToCreateMealEntryPageFailed(
                { error },
              ),
          }),
        ),
      ),
    ),
  { functional: true },
);

export const navigateToCurrentMeal$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(
        CurrentMealApiActions.addMealEntrySuccessful,
        EditMealEntryPageComponentActions.saveClicked,
        EditMealEntryPageComponentActions.deleteMealEntryClicked,
        EditMealEntryPageComponentActions.goBackIconClicked,
      ),
      switchMap(() =>
        from(router.navigate(['app', 'current-meal'])).pipe(
          mapResponse({
            next: () =>
              CurrentMealRouterEffectsActions.navigationToCurrentMealPageSuccessful(),
            error: (error) =>
              CurrentMealRouterEffectsActions.navigationToCurrentMealPageFailed(
                { error },
              ),
          }),
        ),
      ),
    ),
  { functional: true },
);

export const navigateToEditCurrentMealEntry$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(CurrentMealPageComponentActions.mealEntryClicked),
      switchMap(({ mealEntry }) =>
        from(
          router.navigate(['app', 'current-meal', mealEntry.productId]),
        ).pipe(
          mapResponse({
            next: () =>
              CurrentMealRouterEffectsActions.navigationToEditMealEntryPageSuccessful(),
            error: (error) =>
              CurrentMealRouterEffectsActions.navigationToEditMealEntryPageFailed(
                { error },
              ),
          }),
        ),
      ),
    ),
  { functional: true },
);
