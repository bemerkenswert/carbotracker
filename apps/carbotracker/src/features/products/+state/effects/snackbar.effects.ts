import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { map, switchMap } from 'rxjs';
import { ProductsApiActions } from '../actions/api.actions';
import {
  CreateProductPageSnackBarActions,
  DeleteProductSnackBarActions,
  EditProductPageSnackBarActions,
} from '../actions/snackbar.actions';

export const showProductWasCreatedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(ProductsApiActions.creatingProductSuccessful),
      switchMap(() =>
        snackBar
          .open('The product was added successfully.')
          .afterOpened()
          .pipe(
            map(() =>
              CreateProductPageSnackBarActions.showCreateProductSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const showCreateProductFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(ProductsApiActions.creatingProductFailed),
      switchMap(() =>
        snackBar
          .open('The product could not be added.')
          .afterOpened()
          .pipe(
            map(() =>
              CreateProductPageSnackBarActions.showCreateProductSnackbarFailure(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

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

export const showUpdateProductFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(ProductsApiActions.updatingProductFailed),
      switchMap(() =>
        snackBar
          .open('The product could not be updated.')
          .afterOpened()
          .pipe(
            map(() =>
              EditProductPageSnackBarActions.showEditProductSnackbarFailure(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const showProductWasDeletedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(ProductsApiActions.deletingProductSuccessful),
      switchMap(() =>
        snackBar
          .open('The product was deleted successfully.')
          .afterOpened()
          .pipe(
            map(() =>
              DeleteProductSnackBarActions.showDeleteProductSnackbarSuccessful(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const showDeleteProductFailedSnackbar$ = createEffect(
  (actions$ = inject(Actions), snackBar = inject(MatSnackBar)) =>
    actions$.pipe(
      ofType(ProductsApiActions.deletingProductFailed),
      switchMap(() =>
        snackBar
          .open('The product could not be deleted.')
          .afterOpened()
          .pipe(
            map(() =>
              DeleteProductSnackBarActions.showDeleteProductSnackbarFailure(),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);
