import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom, mapResponse } from '@ngrx/operators';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Store } from '@ngrx/store';
import { concatMap, EMPTY, exhaustMap, filter, of, switchMap, tap } from 'rxjs';
import { SavedMealsService } from '../../../saved-meals/services/saved-meals.service';
import { authFeature } from '../../../auth/+state/auth.store';
import { settingsFeature } from '../../../settings/+state/settings.store';
import { SavedMealNameDialogService } from '../../../saved-meals/saved-meal-name-dialog/saved-meal-name-dialog.service';
import { LogMealDialogService } from '../../../../meal-logs-feature/log-meal-dialog/log-meal-dialog.service';
import { ConfirmedLogMealDialogResult } from '../../../../meal-logs-feature/log-meal-dialog/log-meal-dialog.model';
import { MealLogsService } from '../../../../meal-logs-feature/services/meal-logs.service';
import { MealLogsApiActions } from '../../../../meal-logs-feature/+state/meal-logs.actions';
import { CurrentMealService } from '../../services/current-meal.service';
import {
  CreateMealEntryPageComponentActions,
  CurrentMealPageComponentActions,
  EditMealEntryPageComponentActions,
} from '../actions/component.actions';
import { CurrentMealApiActions } from '../actions/api.actions';
import { currentMealFeature } from '../current-meal.store';

export const saveCurrentMealAsSavedMeal = createEffect(
  (
    actions$ = inject(Actions),
    store = inject(Store),
    savedMealsService = inject(SavedMealsService),
    savedMealNameDialogService = inject(SavedMealNameDialogService),
  ) =>
    actions$.pipe(
      ofType(CurrentMealPageComponentActions.saveCurrentMealClicked),
      concatLatestFrom(() => [
        store.select(authFeature.selectUserId),
        store.select(currentMealFeature.selectCurrentMeal),
      ]),
      exhaustMap(([, uid, currentMeal]) => {
        if (!uid) {
          return EMPTY;
        }
        return savedMealNameDialogService.open().pipe(
          filter(
            (result): result is { cancelled: false; name: string } =>
              !result.cancelled,
          ),
          exhaustMap(({ name }) =>
            savedMealsService.saveCurrentMeal({ uid, currentMeal, name }).pipe(
              mapResponse({
                next: () => CurrentMealApiActions.saveCurrentMealSuccessful(),
                error: (error) =>
                  CurrentMealApiActions.saveCurrentMealFailed({ error }),
              }),
            ),
          ),
        );
      }),
    ),
  { functional: true },
);

export const saveCurrentMealAsMealLog = createEffect(
  (
    actions$ = inject(Actions),
    store = inject(Store),
    logMealDialogService = inject(LogMealDialogService),
    mealLogsService = inject(MealLogsService),
  ) =>
    actions$.pipe(
      ofType(CurrentMealPageComponentActions.logCurrentMealClicked),
      concatLatestFrom(() => [
        store.select(authFeature.selectUserId),
        store.select(currentMealFeature.selectCurrentMeal),
        store.select(settingsFeature.selectInsulinToCarbRatios),
      ]),
      exhaustMap(([, uid, currentMeal, insulinToCarbRatios]) => {
        if (!uid) {
          return EMPTY;
        }
        return logMealDialogService
          .open({
            mealEntries: currentMeal.mealEntries,
            showInsulinUnits: insulinToCarbRatios.showInsulinUnits ?? false,
            insulinToCarbRatios: {
              breakfast: insulinToCarbRatios.breakfast,
              lunch: insulinToCarbRatios.lunch,
              dinner: insulinToCarbRatios.dinner,
              night: insulinToCarbRatios.night,
            },
          })
          .pipe(
            filter(
              (result): result is ConfirmedLogMealDialogResult =>
                !result.cancelled,
            ),
            exhaustMap(
              ({ date, mealType, estimatedInsulin, actualInsulin, note }) =>
                mealLogsService
                  .createMealLog({
                    mealEntries: currentMeal.mealEntries,
                    mealType,
                    insulinToCarbRatio: insulinToCarbRatios[mealType] ?? 0,
                    estimatedInsulin,
                    actualInsulin,
                    note,
                    date,
                    uid,
                  })
                  .pipe(
                    mapResponse({
                      next: () => MealLogsApiActions.mealLogCreated(),
                      error: (error) =>
                        MealLogsApiActions.mealLogCreationFailed({ error }),
                    }),
                  ),
            ),
          );
      }),
    ),
  { functional: true },
);

export const removeAllMealEntriesOfCurrentMeal$ = createEffect(
  (
    actions$ = inject(Actions),
    currentMealService = inject(CurrentMealService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(CurrentMealPageComponentActions.clearCurrentMealClicked),
      concatLatestFrom(() => [store.select(authFeature.selectUserId)]),
      concatMap(([, uid]) => {
        if (uid) {
          return currentMealService.cleanAllMealEntries({ uid }).pipe(
            mapResponse({
              next: () => CurrentMealApiActions.clearCurrentMealSuccessful(),
              error: (error) =>
                CurrentMealApiActions.clearCurrentMealFailed({ error }),
            }),
          );
        } else {
          return EMPTY;
        }
      }),
    ),
  { functional: true },
);

export const addMealEntryToCurrentMeal = createEffect(
  (
    actions$ = inject(Actions),
    currentMealService = inject(CurrentMealService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(CreateMealEntryPageComponentActions.saveClicked),
      concatLatestFrom(() => [
        store.select(authFeature.selectUserId),
        store.select(currentMealFeature.selectCurrentMeal),
      ]),
      concatMap(([{ product, amount }, uid, currentMeal]) => {
        if (uid) {
          const mealEntry = {
            productId: product.id,
            name: product.name,
            carbs: product.carbs,
            amount,
          };
          return currentMealService
            .addMealEntry({
              currentMeal,
              mealEntry,
              uid,
            })
            .pipe(
              mapResponse({
                next: () => CurrentMealApiActions.addMealEntrySuccessful(),
                error: (error) =>
                  CurrentMealApiActions.addMealEntryFailed({ error }),
              }),
            );
        } else {
          return of();
        }
      }),
    ),
  { functional: true },
);

export const updateMealEntryOfCurrentMeal = createEffect(
  (
    actions$ = inject(Actions),
    currentMealService = inject(CurrentMealService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(EditMealEntryPageComponentActions.saveClicked),
      concatLatestFrom(() => [
        store.select(authFeature.selectUserId),
        store.select(currentMealFeature.selectCurrentMeal),
      ]),
      concatMap(([{ mealEntry }, uid, currentMeal]) => {
        if (uid) {
          return currentMealService.updateMealEntry({
            currentMeal,
            mealEntry,
            uid,
          });
        } else {
          return of();
        }
      }),
    ),
  { functional: true, dispatch: false },
);

export const deleteMealEntryOfCurrentMeal = createEffect(
  (
    actions$ = inject(Actions),
    currentMealService = inject(CurrentMealService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(EditMealEntryPageComponentActions.deleteMealEntryClicked),
      concatLatestFrom(() => [
        store.select(authFeature.selectUserId),
        store.select(currentMealFeature.selectCurrentMeal),
      ]),
      concatMap(([{ mealEntry }, uid, currentMeal]) => {
        if (uid) {
          return currentMealService.deleteMealEntry({
            currentMeal,
            mealEntry,
            uid,
          });
        } else {
          return of();
        }
      }),
    ),
  { functional: true, dispatch: false },
);

export const startStreamingCurrentMeal$ = createEffect(
  (
    actions$ = inject(Actions),
    currentMealService = inject(CurrentMealService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(({ payload }) =>
        payload.event.urlAfterRedirects.startsWith('/app/current-meal'),
      ),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          currentMealService.subscribeToOwnCurrentMeal({ uid });
        }
      }),
    ),
  { dispatch: false, functional: true },
);

export const stopStreamingCurrentMeal$ = createEffect(
  (
    actions$ = inject(Actions),
    currentMealService = inject(CurrentMealService),
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(
        ({ payload }) =>
          !payload.event.urlAfterRedirects.startsWith('/app/current-meal'),
      ),
      tap(() => {
        currentMealService.unsubscribeFromOwnCurrentMeal();
      }),
    ),
  { dispatch: false, functional: true },
);
