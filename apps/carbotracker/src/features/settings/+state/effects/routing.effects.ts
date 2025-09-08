import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { mapResponse } from '@ngrx/operators';
import { from, switchMap } from 'rxjs';
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
          mapResponse({
            next: () =>
              SettingsRouterEffectsActions.navigationToAccountPageSuccessful(),
            error: (error) =>
              SettingsRouterEffectsActions.navigationToAccountPageFailed({
                error,
              }),
          }),
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
          mapResponse({
            next: () =>
              SettingsRouterEffectsActions.navigationToChangePasswordPageSuccessful(),
            error: (error) =>
              SettingsRouterEffectsActions.navigationToChangePasswordPageFailed(
                { error },
              ),
          }),
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
          mapResponse({
            next: () =>
              SettingsRouterEffectsActions.navigationToInsulinToCarbRatiosPageSuccessful(),
            error: (error) =>
              SettingsRouterEffectsActions.navigationToInsulinToCarbRatiosPageFailed(
                { error },
              ),
          }),
        ),
      ),
    ),
  { functional: true },
);
