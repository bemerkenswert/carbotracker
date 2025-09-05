import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { catchError, from, map, of, switchMap } from 'rxjs';
import {
  AccountPageActions,
  ChangePasswordPageActions,
  SettingsPageActions,
} from '../actions/component.actions';
import { SettingsRouterEffectsActions } from '../actions/routing.actions';

export const navigateToAccountPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(
        SettingsPageActions.accountClicked,
        ChangePasswordPageActions.goBackIconClicked,
      ),
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

export const navigateToInsulinToCarbRatiosPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SettingsPageActions.insulinToCarbRatiosClicked),
      switchMap(() =>
        from(
          router.navigate(['app', 'settings', 'insulin-to-carb-ratios']),
        ).pipe(
          map(() =>
            SettingsRouterEffectsActions.navigationToInsulinToCarbRatiosPageSuccessful(),
          ),
          catchError(() =>
            of(
              SettingsRouterEffectsActions.navigationToInsulinToCarbRatiosPageFailed(),
            ),
          ),
        ),
      ),
    ),
  { functional: true },
);
