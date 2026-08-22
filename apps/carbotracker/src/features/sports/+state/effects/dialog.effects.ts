import { inject } from '@angular/core';
import { ConfirmationDialogService } from '@carbotracker/ui';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import { EditSportPageComponentActions } from '../actions/component.actions';
import { DeleteSportConfirmationDialogActions } from '../actions/dialog.actions';

export const showDeleteConfirmationDialog$ = createEffect(
  (
    actions$ = inject(Actions),
    confirmationDialogService = inject(ConfirmationDialogService),
  ) =>
    actions$.pipe(
      ofType(EditSportPageComponentActions.deleteClicked),
      switchMap(({ selectedSport }) =>
        confirmationDialogService
          .openDeleteConfirmationDialog(selectedSport.name)
          .pipe(
            map((data) =>
              data?.confirmed
                ? DeleteSportConfirmationDialogActions.confirmClicked({
                    selectedSport,
                  })
                : DeleteSportConfirmationDialogActions.abortClicked(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);
