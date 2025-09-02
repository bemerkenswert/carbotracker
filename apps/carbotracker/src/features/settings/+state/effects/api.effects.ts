import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom } from '@ngrx/operators';
import { Store } from '@ngrx/store';
import { catchError, filter, map, mergeMap, of, pipe } from 'rxjs';
import { authFeature } from '../../../auth/+state';
import { FactorsService } from '../../services/factors.service';
import { SettingsApiActions } from '../actions/api.actions';
import { FactorsPageActions } from '../actions/component.actions';

const filterNull = <T>() =>
  pipe(filter((value: T | null): value is T => Boolean(value)));

export const createFactors$ = createEffect(
  (
    actions$ = inject(Actions),
    store = inject(Store),
    factorsService = inject(FactorsService),
  ) =>
    actions$.pipe(
      ofType(FactorsPageActions.saveChangesClicked),
      concatLatestFrom(() =>
        store.select(authFeature.selectUserId).pipe(filterNull()),
      ),
      map(([{ factors }, userId]) => ({
        ...factors,
        creator: userId,
      })),
      mergeMap((newFactors) =>
        factorsService.createFactors({ ...newFactors }).pipe(
          map(() => SettingsApiActions.creatingFactorsSuccessful()),
          catchError((error) =>
            of(SettingsApiActions.creatingFactorsFailed(error)),
          ),
        ),
      ),
    ),
  { dispatch: true, functional: true },
);
