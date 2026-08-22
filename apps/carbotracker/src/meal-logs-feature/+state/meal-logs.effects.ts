import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom, mapResponse } from '@ngrx/operators';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Store } from '@ngrx/store';
import { EMPTY, filter, from, map, merge, switchMap, tap } from 'rxjs';
import { authFeature } from '../../features/auth/+state/auth.store';
import { ConfirmationDialogService } from '@carbotracker/ui';
import { EditMealLogDialogService } from '../edit-meal-log-dialog/edit-meal-log-dialog.service';
import { ConfirmedEditMealLogDialogResult } from '../edit-meal-log-dialog/edit-meal-log-dialog.model';
import { InsulinDoseDialogService } from '../insulin-dose-dialog/insulin-dose-dialog.service';
import { ConfirmedInsulinDoseDialogResult } from '../insulin-dose-dialog/insulin-dose-dialog.model';
import { SportDialogService } from '../sport-dialog/sport-dialog.service';
import { ConfirmedSportDialogResult } from '../sport-dialog/sport-dialog.model';
import { MealLogsService } from '../services/meal-logs.service';
import { MealLog } from '../meal-log.model';
import { fromDateString } from '../date.util';
import { mealLogsFeature } from './meal-logs.feature';
import {
  HistoryPageComponentActions,
  MealLogsApiActions,
  MealLogsSnackBarActions,
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
            (result): result is ConfirmedInsulinDoseDialogResult =>
              !result.cancelled,
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

export const createSportLog$ = createEffect(
  (
    actions$ = inject(Actions),
    sportDialogService = inject(SportDialogService),
    mealLogsService = inject(MealLogsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(HistoryPageComponentActions.logSportClicked),
      concatLatestFrom(() => [
        store.select(authFeature.selectUserId),
        store.select(mealLogsFeature.selectSelectedDate),
      ]),
      switchMap(([, uid, selectedDate]) => {
        if (!uid) {
          return EMPTY;
        }
        return sportDialogService
          .open(
            selectedDate
              ? { defaultDate: fromDateString(selectedDate) }
              : undefined,
          )
          .pipe(
            filter(
              (result): result is ConfirmedSportDialogResult =>
                !result.cancelled,
            ),
            switchMap(
              ({
                date,
                duration,
                sportName,
                basalRate,
                basalReductionPercent,
                note,
              }) =>
                mealLogsService
                  .createSportLog({
                    date,
                    duration,
                    sportName,
                    basalRate,
                    basalReductionPercent,
                    note,
                    uid,
                  })
                  .pipe(
                    mapResponse({
                      next: () => MealLogsApiActions.sportLogCreated(),
                      error: (error) =>
                        MealLogsApiActions.sportLogCreationFailed({ error }),
                    }),
                  ),
            ),
          );
      }),
    ),
  { functional: true },
);

export const editInsulinDose$ = createEffect(
  (
    actions$ = inject(Actions),
    insulinDoseDialogService = inject(InsulinDoseDialogService),
    mealLogsService = inject(MealLogsService),
  ) =>
    actions$.pipe(
      ofType(HistoryPageComponentActions.editInsulinDoseClicked),
      switchMap(({ mealLog }) => {
        if (mealLog.type !== 'insulin-dose') {
          return EMPTY;
        }
        return insulinDoseDialogService
          .open({
            dose: {
              createdAt: mealLog.createdAt,
              insulin: mealLog.insulin,
              note: mealLog.note,
            },
          })
          .pipe(
            filter(
              (result): result is ConfirmedInsulinDoseDialogResult =>
                !result.cancelled,
            ),
            switchMap(({ date, insulin, note }) =>
              mealLogsService
                .updateInsulinDose({
                  id: mealLog.id,
                  date,
                  insulin,
                  note,
                })
                .pipe(
                  mapResponse({
                    next: () => MealLogsApiActions.insulinDoseUpdated(),
                    error: (error) =>
                      MealLogsApiActions.insulinDoseUpdateFailed({ error }),
                  }),
                ),
            ),
          );
      }),
    ),
  { functional: true },
);

export const editMealLog$ = createEffect(
  (
    actions$ = inject(Actions),
    editMealLogDialogService = inject(EditMealLogDialogService),
    mealLogsService = inject(MealLogsService),
  ) =>
    actions$.pipe(
      ofType(HistoryPageComponentActions.editMealLogClicked),
      switchMap(({ mealLog }) => {
        if (mealLog.type !== 'meal-log') {
          return EMPTY;
        }
        return editMealLogDialogService
          .open({
            mealLog: {
              createdAt: mealLog.createdAt,
              mealType: mealLog.mealType,
              estimatedInsulin: mealLog.estimatedInsulin,
              actualInsulin: mealLog.actualInsulin,
              note: mealLog.note,
            },
          })
          .pipe(
            filter(
              (result): result is ConfirmedEditMealLogDialogResult =>
                !result.cancelled,
            ),
            switchMap(({ date, mealType, actualInsulin, note }) =>
              mealLogsService
                .updateMealLog({
                  id: mealLog.id,
                  date,
                  mealType,
                  actualInsulin,
                  note,
                })
                .pipe(
                  mapResponse({
                    next: () => MealLogsApiActions.mealLogUpdated(),
                    error: (error) =>
                      MealLogsApiActions.mealLogUpdateFailed({ error }),
                  }),
                ),
            ),
          );
      }),
    ),
  { functional: true },
);

export const deleteMealLogDocument$ = createEffect(
  (
    actions$ = inject(Actions),
    confirmationDialogService = inject(ConfirmationDialogService),
    mealLogsService = inject(MealLogsService),
  ) =>
    actions$.pipe(
      ofType(HistoryPageComponentActions.deleteMealLogDocumentClicked),
      switchMap(({ mealLog }) =>
        confirmationDialogService
          .openDeleteConfirmationDialog('this entry')
          .pipe(
            filter((result) => result?.confirmed === true),
            switchMap(() =>
              mealLogsService.deleteMealLogDocument({ id: mealLog.id }).pipe(
                mapResponse({
                  next: () => MealLogsApiActions.mealLogDocumentDeleted(),
                  error: (error) =>
                    MealLogsApiActions.mealLogDocumentDeletionFailed({ error }),
                }),
              ),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const reloadMealLogIntoMeal$ = createEffect(
  (
    actions$ = inject(Actions),
    mealLogsService = inject(MealLogsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(HistoryPageComponentActions.reloadMealLogIntoMealClicked),
      concatLatestFrom(() => store.select(authFeature.selectUserId)),
      switchMap(([{ mealLog }, uid]) => {
        if (!uid || mealLog.type !== 'meal-log') {
          return EMPTY;
        }
        const meal = mealLog as MealLog;
        return mealLogsService
          .reloadMealIntoCurrentMeal({
            uid,
            mealEntries: meal.mealEntries,
          })
          .pipe(
            mapResponse({
              next: () => MealLogsApiActions.mealLogReloadedIntoMeal(),
              error: (error) =>
                MealLogsApiActions.mealLogReloadIntoMealFailed({ error }),
            }),
          );
      }),
    ),
  { functional: true },
);

export const showReloadIntoMealSuccessfulSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(MealLogsApiActions.mealLogReloadedIntoMeal),
      switchMap(() => {
        const snackBarRef = snackBar.open(
          'The meal was loaded into the current meal.',
          'Go to Current Meal',
        );
        const opened$ = snackBarRef
          .afterOpened()
          .pipe(
            map(() =>
              MealLogsSnackBarActions.showReloadIntoMealSnackbarSuccessful(),
            ),
          );
        const goToCurrentMealClicked$ = snackBarRef.afterDismissed().pipe(
          filter(({ dismissedByAction }) => dismissedByAction),
          map(() => MealLogsSnackBarActions.goToCurrentMealClicked()),
        );
        return merge(opened$, goToCurrentMealClicked$);
      }),
    ),
  { functional: true },
);

export const showReloadIntoMealFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(MealLogsApiActions.mealLogReloadIntoMealFailed),
      switchMap(() =>
        snackBar
          .open('The meal could not be loaded into the current meal.')
          .afterOpened()
          .pipe(
            map(() =>
              MealLogsSnackBarActions.showReloadIntoMealSnackbarFailed(),
            ),
          ),
      ),
    ),
  { functional: true },
);

export const navigateToCurrentMeal$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(MealLogsSnackBarActions.goToCurrentMealClicked),
      switchMap(() => from(router.navigate(['app', 'current-meal']))),
    ),
  { functional: true, dispatch: false },
);
