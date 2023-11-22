import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { AuthError, AuthErrorCodes } from 'firebase/auth';
import { catchError, filter, from, map, merge, of, switchMap } from 'rxjs';
import { AuthService } from '../auth-feature/auth.service';
import {
  LoginFormComponentActions,
  RoutingActions,
  SignUpApiActions,
  SignUpFormComponentActions,
  SignUpSnackBarActions,
} from './login.actions';

export const navigateToSignUpPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(LoginFormComponentActions.signUpClicked),
      switchMap(() =>
        from(router.navigate(['login', 'sign-up'])).pipe(
          map(() => RoutingActions.navigationToSignUpPageSuccessful()),
          catchError(() => of(RoutingActions.navigationToSignUpPageFailed())),
        ),
      ),
    ),
  { functional: true },
);

export const navigateToLoginPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(
        SignUpFormComponentActions.goBackClicked,
        SignUpSnackBarActions.goToLoginPageClicked,
      ),
      switchMap(() =>
        from(router.navigate(['login'])).pipe(
          map(() => RoutingActions.navigationToLoginPageSuccessful()),
          catchError(() => of(RoutingActions.navigationToLoginPageFailed())),
        ),
      ),
    ),
  { functional: true },
);

export const signUpUser$ = createEffect(
  (actions$ = inject(Actions), authService = inject(AuthService)) =>
    actions$.pipe(
      ofType(SignUpFormComponentActions.signUpClicked),
      switchMap(({ email, password }) =>
        authService.signUp({ email, password }).pipe(
          map(() => SignUpApiActions.signUpSuccessful()),
          catchError((error: AuthError) => {
            switch (error.code) {
              case AuthErrorCodes.EMAIL_EXISTS:
                return of(SignUpApiActions.signUpFailedEmailExists({ email }));
              case AuthErrorCodes.WEAK_PASSWORD:
                return of(SignUpApiActions.signUpFailedWeakPassword());
              default:
                return of(SignUpApiActions.signUpFailedUnknownError());
            }
          }),
        ),
      ),
    ),
  { functional: true },
);

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
      ofType(SignUpApiActions.signUpFailedWeakPassword),
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
