import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import { SportsApiActions } from '../actions/api.actions';
import {
  CreateSportPageSnackBarActions,
  DeleteSportSnackBarActions,
  EditSportPageSnackBarActions,
} from '../actions/snackbar.actions';

export const showSportWasCreatedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SportsApiActions.creatingSportSuccessful),
      switchMap(() =>
        snackBar
          .open('The sport was added successfully.')
          .afterOpened()
          .pipe(
            map(() =>
              CreateSportPageSnackBarActions.showCreateSportSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const showCreateSportFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SportsApiActions.creatingSportFailed),
      switchMap(() =>
        snackBar
          .open('The sport could not be added.')
          .afterOpened()
          .pipe(
            map(() =>
              CreateSportPageSnackBarActions.showCreateSportSnackbarFailure(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const showSportWasChangedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SportsApiActions.updatingSportSuccessful),
      switchMap(() =>
        snackBar
          .open('The sport was updated successfully.')
          .afterOpened()
          .pipe(
            map(() =>
              EditSportPageSnackBarActions.showEditSportSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const showUpdateSportFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SportsApiActions.updatingSportFailed),
      switchMap(() =>
        snackBar
          .open('The sport could not be updated.')
          .afterOpened()
          .pipe(
            map(() =>
              EditSportPageSnackBarActions.showEditSportSnackbarFailure(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const showSportWasDeletedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SportsApiActions.deletingSportSuccessful),
      switchMap(() =>
        snackBar
          .open('The sport was deleted successfully.')
          .afterOpened()
          .pipe(
            map(() =>
              DeleteSportSnackBarActions.showDeleteSportSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const showDeleteSportFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SportsApiActions.deletingSportFailed),
      switchMap(() =>
        snackBar
          .open('The sport could not be deleted.')
          .afterOpened()
          .pipe(
            map(() =>
              DeleteSportSnackBarActions.showDeleteSportSnackbarFailure(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);
