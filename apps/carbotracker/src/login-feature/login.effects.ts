import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { Store } from '@ngrx/store';
import { AuthError, AuthErrorCodes } from 'firebase/auth';
import { catchError, from, map, of, switchMap } from 'rxjs';
import { AppRouterEffectsActions } from '../app/app.actions';
import { SnackbarComponent } from '../app/snackbar/snackbar.component';
import { authFeature } from '../auth-feature/auth.reducer';
import { AuthService } from '../auth-feature/auth.service';
import {
  LoginFormComponentActions,
  RoutingActions,
  SignUpFormComponentActions,
} from './login.actions';

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
        AppRouterEffectsActions.navigateToLoginPage,
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

export const signUpUser$ = createEffect(
  (actions$ = inject(Actions), authService = inject(AuthService)) =>
    actions$.pipe(
      ofType(SignUpFormComponentActions.signUpClicked),
      switchMap(({ email, password }) =>
        authService.signUp({ email, password }).pipe(
          map(() => SignUpFormComponentActions.signUpSuccessful()),
          catchError((error: AuthError) => {
            if (error.code === AuthErrorCodes.EMAIL_EXISTS) {
              return of(
                SignUpFormComponentActions.signUpFailedEmailExists({ email }),
              );
            } else if (error.code === AuthErrorCodes.WEAK_PASSWORD) {
              return of(SignUpFormComponentActions.signUpFailedWeakPassword());
            } else {
              return of(SignUpFormComponentActions.signUpFailedUnknownError());
            }
          }),
        ),
      ),
    ),
  { functional: true },
);

export const showSnackbarWithSignUpError$ = createEffect(
  (
    actions$ = inject(Actions),
    snackBar = inject(MatSnackBar),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(
        SignUpFormComponentActions.signUpFailedEmailExists,
        SignUpFormComponentActions.signUpFailedWeakPassword,
      ),
      switchMap((email) =>
        store.select(authFeature.selectError).pipe(
          switchMap((error) =>
            of(
              snackBar.openFromComponent(SnackbarComponent, {
                data: { label: error, action: 'Go To Login', email },
                // duration: 5000,
              }),
            ).pipe(
              map(() =>
                SignUpFormComponentActions.signUpShowedSnackbarWithErrorSuccessful(),
              ),
              catchError(() =>
                of(
                  SignUpFormComponentActions.signUpShowedSnackbarWithErrorFailed(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  { functional: true },
);
