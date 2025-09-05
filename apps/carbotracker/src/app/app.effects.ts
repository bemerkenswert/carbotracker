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
import { InsulinToCarbRatiosService } from '../features/settings/services/insulin-to-carb-ratios.service';
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

export const startStreamingInsulinToCarbRatios$ = createEffect(
  (
    actions$ = inject(Actions),
    insulinToCarbRatiosService = inject(InsulinToCarbRatiosService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(
        LoginApiActions.loginSuccessful,
        AuthApiActions.userIsLoggedIn,
        SettingsApiActions.creatingInsulinToCarbRatioSuccessful,
        SettingsApiActions.updatingInsulinToCarbRatioSuccessful,
      ),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          insulinToCarbRatiosService.subscribeToOwnInsulinToCarbRatios({ uid });
        }
      }),
    ),
  { dispatch: false, functional: true },
);

export const stopStreamingInsulinToCarbRatios$ = createEffect(
  (
    actions$ = inject(Actions),
    insulinToCarbRatiosService = inject(InsulinToCarbRatiosService),
  ) =>
    actions$.pipe(
      ofType(LogoutApiActions.logoutSuccessful),
      tap(() => {
        insulinToCarbRatiosService.unsubscribeFromOwnInsulinToCarbRatios();
      }),
    ),
  { dispatch: false, functional: true },
);
