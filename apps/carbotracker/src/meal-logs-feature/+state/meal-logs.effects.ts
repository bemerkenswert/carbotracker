import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom, mapResponse } from '@ngrx/operators';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Store } from '@ngrx/store';
import { EMPTY, filter, switchMap, tap } from 'rxjs';
import { authFeature } from '../../features/auth/+state/auth.store';
import { InsulinDoseDialogService } from '../insulin-dose-dialog/insulin-dose-dialog.service';
import { MealLogsService } from '../services/meal-logs.service';
import {
  HistoryPageComponentActions,
  MealLogsApiActions,
} from './meal-logs.actions';

export const startStreamingMealLogs$ = createEffect(
  (
    actions$ = inject(Actions),
    mealLogsService = inject(MealLogsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(({ payload }) =>
        payload.event.urlAfterRedirects.startsWith('/app/history'),
      ),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          mealLogsService.subscribeToOwnMealLogs({ uid });
        }
      }),
    ),
  { dispatch: false, functional: true },
);

export const stopStreamingMealLogs$ = createEffect(
  (actions$ = inject(Actions), mealLogsService = inject(MealLogsService)) =>
    actions$.pipe(
      ofType(HistoryPageComponentActions.leftHistoryPage),
      tap(() => {
        mealLogsService.unsubscribeFromOwnMealLogs();
      }),
    ),
  { dispatch: false, functional: true },
);

export const createInsulinDose$ = createEffect(
  (
    actions$ = inject(Actions),
    insulinDoseDialogService = inject(InsulinDoseDialogService),
    mealLogsService = inject(MealLogsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(HistoryPageComponentActions.logInsulinDoseClicked),
      concatLatestFrom(() => store.select(authFeature.selectUserId)),
      switchMap(([, uid]) => {
        if (!uid) {
          return EMPTY;
        }
        return insulinDoseDialogService.open().pipe(
          filter(
            (
              result,
            ): result is {
              cancelled: false;
              date: Date;
              insulin: number;
              note: string | null;
            } => !result.cancelled,
          ),
          switchMap(({ date, insulin, note }) =>
            mealLogsService
              .createInsulinDose({ date, insulin, note, uid })
              .pipe(
                mapResponse({
                  next: () => MealLogsApiActions.insulinDoseCreated(),
                  error: (error) =>
                    MealLogsApiActions.insulinDoseCreationFailed({ error }),
                }),
              ),
          ),
        );
      }),
    ),
  { functional: true },
);
