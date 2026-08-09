import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { ConfirmationDialogService } from '@carbotracker/ui';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom } from '@ngrx/operators';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Store } from '@ngrx/store';
import { EMPTY, exhaustMap, filter, from, switchMap, tap } from 'rxjs';
import { authFeature } from '../../features/auth/+state/auth.store';
import { SavedMealsService } from '../services/saved-meals.service';
import {
  SavedMealPageComponentActions,
  SavedMealsPageComponentActions,
} from './saved-meals.actions';

export const deleteSavedMeal = createEffect(
  (
    actions$ = inject(Actions),
    store = inject(Store),
    savedMealsService = inject(SavedMealsService),
    confirmationDialogService = inject(ConfirmationDialogService),
    router = inject(Router),
  ) =>
    actions$.pipe(
      ofType(SavedMealPageComponentActions.deleteClicked),
      concatLatestFrom(() => store.select(authFeature.selectUserId)),
      switchMap(([{ savedMeal }, uid]) => {
        if (!uid) {
          return EMPTY;
        }
        return confirmationDialogService
          .openDeleteConfirmationDialog(savedMeal.name)
          .pipe(
            filter((data) => data?.confirmed === true),
            switchMap(() =>
              from(savedMealsService.deleteSavedMeal(savedMeal.id)),
            ),
            switchMap(() => from(router.navigate(['app', 'saved-meals']))),
          );
      }),
    ),
  { dispatch: false, functional: true },
);

export const startStreamingSavedMeals$ = createEffect(
  (
    actions$ = inject<Actions>(Actions),
    savedMealsService = inject(SavedMealsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(({ payload }) =>
        payload.event.urlAfterRedirects.startsWith('/app/saved-meals'),
      ),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          savedMealsService.subscribeToOwnSavedMeals({ uid });
        }
      }),
    ),
  { dispatch: false, functional: true },
);

export const stopStreamingSavedMeals$ = createEffect(
  (
    actions$ = inject<Actions>(Actions),
    savedMealsService = inject(SavedMealsService),
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(
        ({ payload }) =>
          !payload.event.urlAfterRedirects.startsWith('/app/saved-meals'),
      ),
      tap(() => {
        savedMealsService.unsubscribeFromOwnSavedMeals();
      }),
    ),
  { dispatch: false, functional: true },
);

export const navigateToSavedMeal$ = createEffect(
  (actions$ = inject<Actions>(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SavedMealsPageComponentActions.savedMealClicked),
      exhaustMap(({ savedMeal }) =>
        from(router.navigate(['app', 'saved-meals', savedMeal.id])),
      ),
    ),
  { dispatch: false, functional: true },
);
