import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { catchError, from, map, of, switchMap } from 'rxjs';
import {
  LoginFormComponentActions,
  RoutingActions,
  SignUpFormComponentActions,
} from './login.actions';
import { SignUpService } from './sign-up.service';

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

export const goBack$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SignUpFormComponentActions.goBackClicked),
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
  (actions$ = inject(Actions), signUpService = inject(SignUpService)) =>
    actions$.pipe(
      ofType(SignUpFormComponentActions.signUpClicked),
      switchMap(({ email, password }) =>
        signUpService.signUp({ email, password }).pipe(
          map(() => SignUpFormComponentActions.signUpSuccessful()),
          catchError(() => of(SignUpFormComponentActions.signUpFailed())),
        ),
      ),
    ),
  { functional: true },
);
