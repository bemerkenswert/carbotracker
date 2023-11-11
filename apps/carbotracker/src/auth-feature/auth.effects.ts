import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { catchError, exhaustMap, map, of } from 'rxjs';
import { LoginFormComponentActions } from '../login-feature/login.actions';
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
          catchError((error) => of(AuthApiActions.loginFailed({ error }))),
        ),
      ),
    ),
  { functional: true },
);
