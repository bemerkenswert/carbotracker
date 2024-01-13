import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { Actions, concatLatestFrom, createEffect, ofType } from '@ngrx/effects';
import { AuthError, AuthErrorCodes } from 'firebase/auth';
import { catchError, filter, from, map, of, switchMap } from 'rxjs';
import { AuthService } from '../features/auth/services/auth.service';
import {
  AccountPageActions,
  AccountPageSnackBarActions,
  SettingsApiActions,
  SettingsPageActions,
  SettingsRouterEffectsActions,
} from './settings.actions';

export const updateEmail$ = createEffect(
  (actions$ = inject(Actions), authService = inject(AuthService)) =>
    actions$.pipe(
      ofType(AccountPageActions.saveChangesClicked),
      concatLatestFrom(() => authService.getUser()),
      filter(([{ email }, user]) => user.email !== email),
      switchMap(([{ email }, user]) =>
        authService.updateEmail(user, email).pipe(
          map(() => SettingsApiActions.updateEmailSuccessful({ email })),
          catchError((error: AuthError) => {
            switch (error.code) {
              case AuthErrorCodes.EMAIL_EXISTS:
                return of(SettingsApiActions.updateEmailFailedEmailExists());
              default:
                return of(SettingsApiActions.updateEmailFailed({ error }));
            }
          }),
        ),
      ),
    ),
  { functional: true },
);

export const showEmailAlreadyExistsSnackBar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(SettingsApiActions.updateEmailFailedEmailExists),
      switchMap(() =>
        snackBar
          .open('This email address already exists.')
          .afterOpened()
          .pipe(
            map(() =>
              AccountPageSnackBarActions.showEmailAlreadyExistsSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { functional: true },
);

// export const updatePassword$ = createEffect(
//   (actions$ = inject(Actions), authService = inject(AuthService)) =>
//     actions$.pipe(
//       ofType(AccountPageActions.saveChangesClicked),
//       concatLatestFrom(() => authService.getUser()),
//       filter(([{ password }]) => !!password),
//       switchMap(([{ password }, user]) =>
//         authService.updatePassword(user, password).pipe(
//           map(() => SettingsApiActions.updatePasswordSuccessful()),
//           catchError((error: AuthError) => {
//             switch (error.code) {
//               case AuthErrorCodes.WEAK_PASSWORD:
//                 return of(
//                   SettingsApiActions.updatePasswordFailedWeakPassword(),
//                 );
//               default:
//                 return of(SettingsApiActions.updatePasswordFailed({ error }));
//             }
//           }),
//         ),
//       ),
//     ),
//   { functional: true },
// );

export const showPasswordWasChangedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(
        SettingsApiActions.updatePasswordSuccessful,
        SettingsApiActions.updateEmailSuccessful,
      ),
      switchMap(() =>
        snackBar
          .open('Your changes were successful.')
          .afterOpened()
          .pipe(
            map(() => AccountPageSnackBarActions.changesSuccessfulSnackbar()),
          ),
      ),
    ),
  { functional: true },
);

export const navigateToAccountPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SettingsPageActions.accountClicked),
      switchMap(() =>
        from(router.navigate(['app', 'settings', 'account'])).pipe(
          map(() =>
            SettingsRouterEffectsActions.navigationToAccountPageSuccessful(),
          ),
          catchError(() =>
            of(SettingsRouterEffectsActions.navigationToAccountPageFailed()),
          ),
        ),
      ),
    ),
  { functional: true },
);

export const navigateToChangePasswordPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(AccountPageActions.passwordInputFocused),
      switchMap(() =>
        from(router.navigate(['app', 'settings', 'change-password'])).pipe(
          map(() =>
            SettingsRouterEffectsActions.navigationToChangePasswordPageSuccessful(),
          ),
          catchError(() =>
            of(
              SettingsRouterEffectsActions.navigationToChangePasswordPageFailed(),
            ),
          ),
        ),
      ),
    ),
  { functional: true },
);
