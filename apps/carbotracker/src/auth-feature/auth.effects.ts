import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { LoginFormComponentActions } from '../login-feature/login.actions';
import { catchError, exhaustMap, map, of, tap } from 'rxjs';
import { AuthService } from './auth.service';
import { AuthApiActions } from './auth.actions';

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
