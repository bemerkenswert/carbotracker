import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom } from '@ngrx/operators';
import { Store } from '@ngrx/store';
import { catchError, filter, map, mergeMap, of, pipe } from 'rxjs';
import { authFeature } from '../../../auth/+state';
import { InsulinToCarbRatiosService } from '../../services/insulin-to-carb-ratios.service';
import { SettingsApiActions } from '../actions/api.actions';
import { InsulinToCarbRatiosPageActions } from '../actions/component.actions';

const filterNull = <T>() =>
  pipe(filter((value: T | null): value is T => Boolean(value)));

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
      map(([{ insulinToCarbRatios }, userId]) => ({
        ...insulinToCarbRatios,
        creator: userId,
      })),
      mergeMap((newInsulinToCarbRatios) =>
        insulinToCarbRatiosService
          .setInsulinToCarbRatios({
            insulinToCarbRatios: newInsulinToCarbRatios,
            uid: newInsulinToCarbRatios.creator,
          })
          .pipe(
            map(() =>
              SettingsApiActions.settingInsulinToCarbRatiosSuccessful(),
            ),
            catchError((error) =>
              of(SettingsApiActions.settingInsulinToCarbRatiosFailed(error)),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);
