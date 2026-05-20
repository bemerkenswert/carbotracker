import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { exhaustMap, from } from 'rxjs';
import {
  CreateMealEntryPageComponentActions,
  CurrentMealPageComponentActions,
  EditMealEntryPageComponentActions,
} from '../actions/component.actions';

export const navigateToCreateMealEntry$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(CurrentMealPageComponentActions.addClicked),
      exhaustMap(() =>
        from(router.navigate(['app', 'current-meal', 'create'])),
      ),
    ),
  { dispatch: false, functional: true },
);

export const navigateToCurrentMeal$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(
        CreateMealEntryPageComponentActions.saveClicked,
        EditMealEntryPageComponentActions.saveClicked,
        EditMealEntryPageComponentActions.deleteMealEntryClicked,
      ),
      exhaustMap(() => from(router.navigate(['app', 'current-meal']))),
    ),
  { dispatch: false, functional: true },
);

export const navigateToEditCurrentMealEntry$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(CurrentMealPageComponentActions.mealEntryClicked),
      exhaustMap(({ mealEntry }) =>
        from(router.navigate(['app', 'current-meal', mealEntry.productId])),
      ),
    ),
  { dispatch: false, functional: true },
);
