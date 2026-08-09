import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import {
  EmailApiActions,
  LoginApiActions,
  PasswordApiActions,
} from '../../../auth/+state';
import { SettingsApiActions } from '../actions/api.actions';
import {
  AccountPageSnackBarActions,
  ChangePasswordPageSnackBarActions,
  InsulinToCarbRatiosPageSnackBarActions,
} from '../actions/snackbar.actions';

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

export const showOldPasswordWasWrongSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(LoginApiActions.reauthenticateFailedWrongPassword),
      switchMap(() =>
        snackBar
          .open('Old password is wrong. Please try again.')
          .afterOpened()
          .pipe(
            map(() =>
              ChangePasswordPageSnackBarActions.showOldPasswordWasWrongSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showInsulinToCarbRatiosWereUpdatedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SettingsApiActions.settingInsulinToCarbRatiosSuccessful),
      switchMap(() =>
        snackBar
          .open('Your ratios were updated.')
          .afterOpened()
          .pipe(
            map(() =>
              InsulinToCarbRatiosPageSnackBarActions.showInsulinToCarbRatiosUpdatedSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showInsulinToCarbRatiosUpdateFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SettingsApiActions.settingInsulinToCarbRatiosFailed),
      switchMap(() =>
        snackBar
          .open('Your ratios could not be updated.')
          .afterOpened()
          .pipe(
            map(() =>
              InsulinToCarbRatiosPageSnackBarActions.showInsulinToCarbRatiosUpdateFailedSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);
