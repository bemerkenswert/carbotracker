import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import { CurrentMealApiActions } from '../actions/api.actions';
import { CurrentMealSnackBarActions } from '../actions/snackbar.actions';

export const showAddMealEntrySuccessfulSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(CurrentMealApiActions.addMealEntrySuccessful),
      switchMap(() =>
        snackBar
          .open('The meal entry was added.')
          .afterOpened()
          .pipe(
            map(() =>
              CurrentMealSnackBarActions.showAddMealEntrySnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showAddMealEntryFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(CurrentMealApiActions.addMealEntryFailed),
      switchMap(() =>
        snackBar
          .open('The meal entry could not be added.')
          .afterOpened()
          .pipe(
            map(() =>
              CurrentMealSnackBarActions.showAddMealEntrySnackbarFailed(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showClearCurrentMealSuccessfulSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(CurrentMealApiActions.clearCurrentMealSuccessful),
      switchMap(() =>
        snackBar
          .open('The current meal was cleared.')
          .afterOpened()
          .pipe(
            map(() =>
              CurrentMealSnackBarActions.showClearCurrentMealSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showClearCurrentMealFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(CurrentMealApiActions.clearCurrentMealFailed),
      switchMap(() =>
        snackBar
          .open('The current meal could not be cleared.')
          .afterOpened()
          .pipe(
            map(() =>
              CurrentMealSnackBarActions.showClearCurrentMealSnackbarFailed(),
            ),
          ),
      ),
    ),
  { functional: true },
);
