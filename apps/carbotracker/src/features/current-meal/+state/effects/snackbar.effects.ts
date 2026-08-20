import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import { MealLogsApiActions } from '../../../../meal-logs-feature/+state/meal-logs.actions';
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

export const showSaveCurrentMealSuccessfulSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(CurrentMealApiActions.saveCurrentMealSuccessful),
      switchMap(() =>
        snackBar
          .open('The meal was saved.')
          .afterOpened()
          .pipe(
            map(() =>
              CurrentMealSnackBarActions.showSaveCurrentMealSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showSaveCurrentMealFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(CurrentMealApiActions.saveCurrentMealFailed),
      switchMap(() =>
        snackBar
          .open('The meal could not be saved.')
          .afterOpened()
          .pipe(
            map(() =>
              CurrentMealSnackBarActions.showSaveCurrentMealSnackbarFailed(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showMealLogSavedSuccessfulSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(MealLogsApiActions.mealLogCreated),
      switchMap(() =>
        snackBar
          .open('The meal was logged.')
          .afterOpened()
          .pipe(
            map(() =>
              CurrentMealSnackBarActions.showLogMealSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showMealLogSavedFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(MealLogsApiActions.mealLogCreationFailed),
      switchMap(() =>
        snackBar
          .open('The meal could not be logged.')
          .afterOpened()
          .pipe(
            map(() => CurrentMealSnackBarActions.showLogMealSnackbarFailed()),
          ),
      ),
    ),
  { functional: true },
);
