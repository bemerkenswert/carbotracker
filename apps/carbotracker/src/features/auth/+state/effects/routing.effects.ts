import { DOCUMENT } from '@angular/common';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom } from '@ngrx/operators';
import { routerNavigatedAction } from '@ngrx/router-store';
import { catchError, from, map, of, switchMap, tap } from 'rxjs';
import { LoginApiActions, LogoutApiActions } from '../actions/api.actions';
import {
  LoginFormComponentActions,
  SignUpFormComponentActions,
} from '../actions/component.actions';
import { RoutingActions } from '../actions/routing.actions';
import { SignUpSnackBarActions } from '../actions/snackbar.actions';

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
        LogoutApiActions.logoutSuccessful,
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

/**
 * Reload App is needed because of a strange firebase bug.
 * After login, the initial products don't load. Also on logout
 * the app crashes. Remove this effect to debug further. At the
 * moment the app get's reloaded in the following cases:
 * 1. login success -> navigation to other view --> reload
 * 2. logout success -> navigation to other view --> reload
 *
 */
export const reloadApp$ = createEffect(
  (actions$ = inject(Actions), document = inject(DOCUMENT)) =>
    actions$.pipe(
      ofType(
        LoginApiActions.loginSuccessful,
        LogoutApiActions.logoutSuccessful,
      ),
      concatLatestFrom(() => actions$.pipe(ofType(routerNavigatedAction))),
      tap(() => document.location.reload()),
    ),
  { functional: true, dispatch: false },
);
