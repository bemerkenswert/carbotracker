import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { Store } from '@ngrx/store';
import { catchError, from, map, of, switchMap, tap } from 'rxjs';
import { authFeature } from '../features/auth/+state';
import {
  AuthApiActions,
  LoginApiActions,
  LogoutApiActions,
  SignUpApiActions,
} from '../features/auth/+state/actions/api.actions';
import { SettingsApiActions } from '../features/settings/+state';
import { FactorsService } from '../features/settings/services/factors.service';
import { AppRouterEffectsActions } from './app.actions';

export const navigateToProducts$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(LoginApiActions.loginSuccessful),
      switchMap(() => from(router.navigate(['app', 'products']))),
    ),
  { functional: true, dispatch: false },
);

export const navigateToApp$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SignUpApiActions.signUpSuccessful),
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

export const startStreamingFactors$ = createEffect(
  (
    actions$ = inject(Actions),
    factorsService = inject(FactorsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(
        LoginApiActions.loginSuccessful,
        AuthApiActions.userIsLoggedIn,
        SettingsApiActions.creatingFactorsSuccessful,
        SettingsApiActions.updatingFactorsSuccessful,
      ),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          factorsService.subscribeToOwnFactors({ uid });
        }
      }),
    ),
  { dispatch: false, functional: true },
);

export const stopStreamingFactors$ = createEffect(
  (actions$ = inject(Actions), factorsService = inject(FactorsService)) =>
    actions$.pipe(
      ofType(LogoutApiActions.logoutSuccessful),
      tap(() => {
        factorsService.unsubscribeFromOwnFactors();
      }),
    ),
  { dispatch: false, functional: true },
);
