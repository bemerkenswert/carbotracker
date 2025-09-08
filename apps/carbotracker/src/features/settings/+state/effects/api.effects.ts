import { inject } from '@angular/core';
import { filterNull } from '@carbotracker/utility';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom, mapResponse } from '@ngrx/operators';
import { Store } from '@ngrx/store';
import { switchMap } from 'rxjs';
import { authFeature } from '../../../auth/+state';
import { InsulinToCarbRatiosService } from '../../services/insulin-to-carb-ratios.service';
import { SettingsApiActions } from '../actions/api.actions';
import { InsulinToCarbRatiosPageActions } from '../actions/component.actions';

export const createInsulinToCarbRatios$ = createEffect(
  (
    actions$ = inject(Actions),
    store = inject(Store),
    insulinToCarbRatiosService = inject(InsulinToCarbRatiosService),
  ) =>
    actions$.pipe(
      ofType(InsulinToCarbRatiosPageActions.saveChangesClicked),
      concatLatestFrom(() =>
        store.select(authFeature.selectUserId).pipe(filterNull()),
      ),
      switchMap(([{ insulinToCarbRatios }, userId]) =>
        insulinToCarbRatiosService
          .setInsulinToCarbRatios({
            insulinToCarbRatios,
            uid: userId,
          })
          .pipe(
            mapResponse({
              next: () =>
                SettingsApiActions.settingInsulinToCarbRatiosSuccessful(),
              error: (error) =>
                SettingsApiActions.settingInsulinToCarbRatiosFailed({ error }),
            }),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);
