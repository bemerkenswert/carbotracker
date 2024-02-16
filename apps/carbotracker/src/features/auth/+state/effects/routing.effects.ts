import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { createEffect, Actions, ofType } from '@ngrx/effects';
import { switchMap, from, map, catchError, of } from 'rxjs';
import { LogoutApiActions } from '../actions/api.actions';
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
