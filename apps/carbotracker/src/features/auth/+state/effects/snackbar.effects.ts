import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { filter, map, merge, switchMap } from 'rxjs';
import {
  LoginApiActions,
  PasswordApiActions,
  SignUpApiActions,
} from '../actions/api.actions';
import {
  LoginSnackBarActions,
  SignUpSnackBarActions,
} from '../actions/snackbar.actions';

export const showEmailAlreadyExistsSnackBar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SignUpApiActions.signUpFailedEmailExists),
      switchMap(({ email }) => {
        const snackBarRef = snackBar.open(
          'This email address already exists.',
          'Go To Login',
        );
        const snackBarOpened$ = snackBarRef
          .afterOpened()
          .pipe(
            map(() =>
              SignUpSnackBarActions.showEmailAlreadyExistsSnackbarSuccessful(),
            ),
          );
        const goToLoginPageClicked$ = snackBarRef.afterDismissed().pipe(
          filter(({ dismissedByAction }) => dismissedByAction),
          map(() => SignUpSnackBarActions.goToLoginPageClicked({ email })),
        );
        return merge(snackBarOpened$, goToLoginPageClicked$);
      }),
    ),
  { functional: true },
);

export const showPasswordIsWeakSnackBar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(
        SignUpApiActions.signUpFailedWeakPassword,
        PasswordApiActions.updatePasswordFailedWeakPassword,
      ),
      switchMap(() =>
        snackBar
          .open(
            'This password is too weak, it should be at least 6 characters.',
          )
          .afterOpened()
          .pipe(
            map(() =>
              SignUpSnackBarActions.showPasswordIsWeakSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const showPasswordIsWrongSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(LoginApiActions.loginFailedWrongPassword),
      switchMap(() =>
        snackBar
          .open('This password is wrong, please try again.')
          .afterOpened()
          .pipe(
            map(() =>
              LoginSnackBarActions.showPasswordIsWrongSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);
