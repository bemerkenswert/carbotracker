import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { AuthError, AuthErrorCodes } from 'firebase/auth';
import { catchError, exhaustMap, map, of, switchMap } from 'rxjs';
import { SettingsPageActions } from '../../../../settings-feature/settings.actions';
import { AuthService } from '../../services/auth.service';
import {
  LoginApiActions,
  LogoutApiActions,
  SignUpApiActions,
} from '../actions/api.actions';
import {
  LoginFormComponentActions,
  SignUpFormComponentActions,
} from '../actions/component.actions';

export const loginUser$ = createEffect(
  (actions$ = inject(Actions), authService = inject(AuthService)) =>
    actions$.pipe(
      ofType(LoginFormComponentActions.loginClicked),
      exhaustMap(({ email, password }) =>
        authService.login({ email, password }).pipe(
          map((userCredential) =>
            LoginApiActions.loginSuccessful({ userCredential }),
          ),
          catchError((error: AuthError) => {
            switch (error.code) {
              case AuthErrorCodes.INVALID_PASSWORD:
                return of(LoginApiActions.loginFailedWrongPassword());
              default:
                return of(LoginApiActions.loginFailed({ error }));
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
      ofType(SettingsPageActions.logoutClicked),
      exhaustMap(() =>
        authService.logout().pipe(
          map(() => LogoutApiActions.logoutSuccessful()),
          catchError((error) => of(LogoutApiActions.logoutFailed({ error }))),
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
