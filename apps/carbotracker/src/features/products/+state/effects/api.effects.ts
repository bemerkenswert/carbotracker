import { inject } from '@angular/core';
import { filterNull } from '@carbotracker/utility';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom } from '@ngrx/operators';
import { Store } from '@ngrx/store';
import {
  catchError,
  exhaustMap,
  map,
  mergeMap,
  of,
  switchMap,
  tap,
} from 'rxjs';
import {
  AuthApiActions,
  LogoutApiActions,
} from '../../../auth/+state/actions/api.actions';
import { authFeature } from '../../../auth/+state/auth.store';
import { ProductsService } from '../../services/products.service';
import { ProductsApiActions } from '../actions/api.actions';
import {
  CreateProductPageComponentActions,
  EditProductPageComponentActions,
} from '../actions/component.actions';
import { DeleteProductConfirmationDialogActions } from '../actions/dialog.actions';
import { productsFeature } from '../products.store';

export const startStreamingProducts$ = createEffect(
  (
    actions$ = inject(Actions),
    productsService = inject(ProductsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(AuthApiActions.userIsLoggedIn),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          productsService.subscribeToOwnProducts({ uid });
        }
      }),
    ),
  { dispatch: false, functional: true },
);

export const stopStreamingProducts$ = createEffect(
  (actions$ = inject(Actions), productsService = inject(ProductsService)) =>
    actions$.pipe(
      ofType(LogoutApiActions.logoutSuccessful),
      tap(() => {
        productsService.unsubscribeFromOwnProducts();
      }),
    ),
  { dispatch: false, functional: true },
);

export const updateProduct$ = createEffect(
  (
    actions$ = inject(Actions),
    productsService = inject(ProductsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(EditProductPageComponentActions.saveProductClicked),
      concatLatestFrom(() =>
        store.select(productsFeature.selectCurrentProduct).pipe(filterNull()),
      ),
      exhaustMap(([{ changedProduct }, existingProduct]) =>
        productsService
          .updateProduct({
            ...existingProduct,
            ...changedProduct,
          })
          .pipe(
            map(() => ProductsApiActions.updatingProductSuccessful()),
            catchError((error) =>
              of(ProductsApiActions.updatingProductFailed({ error })),
            ),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const deleteProduct$ = createEffect(
  (actions$ = inject(Actions), productsService = inject(ProductsService)) =>
    actions$.pipe(
      ofType(DeleteProductConfirmationDialogActions.confirmClicked),
      exhaustMap(({ selectedProduct }) =>
        productsService.deleteProduct(selectedProduct.id).pipe(
          map(() => ProductsApiActions.deletingProductSuccessful()),
          catchError((error) =>
            of(ProductsApiActions.deletingProductFailed({ error })),
          ),
        ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const createProduct$ = createEffect(
  (
    actions$ = inject(Actions),
    productsService = inject(ProductsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(CreateProductPageComponentActions.saveProductClicked),
      concatLatestFrom(() =>
        store.select(authFeature.selectUserId).pipe(filterNull()),
      ),
      map(([{ newProduct }, userId]) => ({ ...newProduct, creator: userId })),
      mergeMap((newProduct) =>
        productsService.createProduct({ ...newProduct }).pipe(
          map(() => ProductsApiActions.creatingProductSuccessful()),
          catchError((error) =>
            of(ProductsApiActions.creatingProductFailed(error)),
          ),
        ),
      ),
    ),
  { dispatch: true, functional: true },
);
