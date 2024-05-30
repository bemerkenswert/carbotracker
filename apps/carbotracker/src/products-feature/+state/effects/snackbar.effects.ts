import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import { ProductsApiActions } from '../actions/api.actions';
import { EditProductPageSnackBarActions } from '../actions/snackbar.actions';

export const showProductWasChangedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(ProductsApiActions.updatingProductSuccessful),
      switchMap(() =>
        snackBar
          .open('The product was updated successfully.')
          .afterOpened()
          .pipe(
            map(() =>
              EditProductPageSnackBarActions.showEditProductSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);
