import { inject } from '@angular/core';
import { ConfirmationDialogService } from '@carbotracker/ui';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import { SavedMealPageComponentActions } from '../actions/component.actions';
import { DeleteSavedMealConfirmationDialogActions } from '../actions/dialog.actions';

export const showDeleteConfirmationDialog$ = createEffect(
  (
    actions$ = inject(Actions),
    confirmationDialogService = inject(ConfirmationDialogService),
  ) =>
    actions$.pipe(
      ofType(SavedMealPageComponentActions.deleteClicked),
      switchMap(({ savedMeal }) =>
        confirmationDialogService
          .openDeleteConfirmationDialog(savedMeal.name)
          .pipe(
            map((data) =>
              data?.confirmed
                ? DeleteSavedMealConfirmationDialogActions.confirmClicked({
                    savedMeal,
                  })
                : DeleteSavedMealConfirmationDialogActions.abortClicked(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);
