import { inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { mapResponse } from '@ngrx/operators';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Store } from '@ngrx/store';
import { exhaustMap, filter, from, switchMap, tap } from 'rxjs';
import { authFeature } from '../../../auth/+state/auth.store';
import { SavedMealsService } from '../../services/saved-meals.service';
import { SavedMealsApiActions } from '../actions/api.actions';
import { DeleteSavedMealConfirmationDialogActions } from '../actions/dialog.actions';

export const deleteSavedMeal$ = createEffect(
  (actions$ = inject(Actions), savedMealsService = inject(SavedMealsService)) =>
    actions$.pipe(
      ofType(DeleteSavedMealConfirmationDialogActions.confirmClicked),
      exhaustMap(({ savedMeal }) =>
        from(savedMealsService.deleteSavedMeal(savedMeal.id)).pipe(
          mapResponse({
            next: () => SavedMealsApiActions.deletingSavedMealSuccessful(),
            error: (error) =>
              SavedMealsApiActions.deletingSavedMealFailed({ error }),
          }),
        ),
      ),
    ),
  { functional: true },
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
