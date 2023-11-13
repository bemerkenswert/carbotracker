import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { catchError, from, map, of, switchMap } from 'rxjs';
import { AuthApiActions } from '../auth-feature/auth.actions';
import { SignUpFormComponentActions } from '../login-feature/login.actions';
import { AppRouterEffectsActions } from './app.actions';

export const navigateToProducts$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(AuthApiActions.loginSuccessful),
      switchMap(() => from(router.navigate(['app', 'products']))),
    ),
  { functional: true, dispatch: false },
);

export const navigateToApp$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SignUpFormComponentActions.signUpSuccessful),
      switchMap(() =>
        from(router.navigate(['app'])).pipe(
          map(() => AppRouterEffectsActions.navigationToAppSuccessful()),
          catchError((error) =>
            of(AppRouterEffectsActions.navigationToAppFailed({ error })),
          ),
        ),
      ),
    ),
  { functional: true },
);