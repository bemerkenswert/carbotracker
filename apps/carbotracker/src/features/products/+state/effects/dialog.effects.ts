import { inject } from '@angular/core';
import { ConfirmationDialogService } from '@carbotracker/ui';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import { EditProductPageComponentActions } from '../actions/component.actions';
import { DeleteProductConfirmationDialogActions } from '../actions/dialog.actions';

export const showDeleteConfirmationDialog$ = createEffect(
  (
    actions$ = inject(Actions),
    confirmationDialogService = inject(ConfirmationDialogService),
  ) =>
    actions$.pipe(
      ofType(EditProductPageComponentActions.deleteClicked),
      switchMap(({ selectedProduct }) =>
        confirmationDialogService
          .openDeleteConfirmationDialog(selectedProduct.name)
          .pipe(
            map((data) =>
              data?.confirmed
                ? DeleteProductConfirmationDialogActions.confirmClicked({
                    selectedProduct,
                  })
                : DeleteProductConfirmationDialogActions.abortClicked(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);
