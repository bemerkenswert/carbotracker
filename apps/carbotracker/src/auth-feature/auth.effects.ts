import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { AuthError, AuthErrorCodes } from 'firebase/auth';
import { catchError, exhaustMap, map, of } from 'rxjs';
import { LoginFormComponentActions } from '../login-feature/login.actions';
import { ShellComponentActions } from '../shell-feature/shell.actions';
import { AuthApiActions } from './auth.actions';
import { AuthService } from './auth.service';

export const loginUser$ = createEffect(
  (actions$ = inject(Actions), authService = inject(AuthService)) =>
    actions$.pipe(
      ofType(LoginFormComponentActions.loginClicked),
      exhaustMap(({ email, password }) =>
        authService.login({ email, password }).pipe(
          map((userCredential) =>
            AuthApiActions.loginSuccessful({ userCredential }),
          ),
          catchError((error: AuthError) => {
            switch (error.code) {
              case AuthErrorCodes.INVALID_PASSWORD:
                return of(AuthApiActions.loginFailedWrongPassword());
              default:
                return of(AuthApiActions.loginFailed({ error }));
            }
          }),
        ),
      ),
    ),
  { functional: true },
);

export const logoutUser$ = createEffect(
  (actions$ = inject(Actions), authService = inject(AuthService)) =>
    actions$.pipe(
      ofType(ShellComponentActions.logoutClicked),
      exhaustMap(() =>
        authService.logout().pipe(
          map(() => AuthApiActions.logoutSuccessful()),
          catchError((error) => of(AuthApiActions.logoutFailed({ error }))),
        ),
      ),
    ),
  { functional: true },
);
