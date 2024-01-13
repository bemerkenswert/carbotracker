import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import {
    EmailApiActions,
    PasswordApiActions,
} from '../../../features/auth/+state';
import { AccountPageSnackBarActions } from '../actions/snackbar.actions';

export const showEmailAlreadyExistsSnackBar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(EmailApiActions.updateEmailFailedEmailExists),
      switchMap(() =>
        snackBar
          .open('This email address already exists.')
          .afterOpened()
          .pipe(
            map(() =>
              AccountPageSnackBarActions.showEmailAlreadyExistsSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showPasswordWasChangedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(
        PasswordApiActions.updatePasswordSuccessful,
        EmailApiActions.updateEmailSuccessful,
      ),
      switchMap(() =>
        snackBar
          .open('Your changes were successful.')
          .afterOpened()
          .pipe(
            map(() => AccountPageSnackBarActions.changesSuccessfulSnackbar()),
          ),
      ),
    ),
  { functional: true },
);
