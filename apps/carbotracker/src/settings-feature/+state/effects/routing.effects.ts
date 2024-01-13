import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { createEffect, Actions, ofType } from '@ngrx/effects';
import { switchMap, from, map, catchError, of } from 'rxjs';
import { SettingsPageActions, AccountPageActions } from '../actions/component.actions';
import { SettingsRouterEffectsActions } from '../actions/routing.actions';


export const navigateToAccountPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) => actions$.pipe(
    ofType(SettingsPageActions.accountClicked),
    switchMap(() => from(router.navigate(['app', 'settings', 'account'])).pipe(
      map(() => SettingsRouterEffectsActions.navigationToAccountPageSuccessful()
      ),
      catchError(() => of(SettingsRouterEffectsActions.navigationToAccountPageFailed())
      )
    )
    )
  ),
  { functional: true }
);

export const navigateToChangePasswordPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) => actions$.pipe(
    ofType(AccountPageActions.passwordInputFocused),
    switchMap(() => from(router.navigate(['app', 'settings', 'change-password'])).pipe(
      map(() => SettingsRouterEffectsActions.navigationToChangePasswordPageSuccessful()
      ),
      catchError(() => of(
        SettingsRouterEffectsActions.navigationToChangePasswordPageFailed()
      )
      )
    )
    )
  ),
  { functional: true }
);
