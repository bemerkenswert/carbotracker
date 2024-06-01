import { inject } from '@angular/core';
import { Actions, concatLatestFrom, createEffect, ofType } from '@ngrx/effects';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Store } from '@ngrx/store';
import {
  catchError,
  exhaustMap,
  filter,
  map,
  mergeMap,
  of,
  pipe,
  switchMap,
  tap,
} from 'rxjs';
import { authFeature } from '../../../features/auth/+state/auth.store';
import { SettingsPageActions } from '../../../features/settings/+state';
import { ProductsService } from '../../services/products.service';
import { ProductsApiActions } from '../actions/api.actions';
import {
  CreateProductPageComponentActions,
  EditProductPageComponentActions,
} from '../actions/component.actions';
import { DeleteProductConfirmationDialogActions } from '../actions/dialog.actions';
import { ProductsRouterActions } from '../actions/routing.actions';

const filterNull = <T>() =>
  pipe(filter((value: T | null): value is T => Boolean(value)));

export const startStreamingProducts$ = createEffect(
  (
    actions$ = inject(Actions),
    productsService = inject(ProductsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(({ payload }) =>
        payload.event.urlAfterRedirects.startsWith('/app/products'),
      ),
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
      ofType(
        ProductsRouterActions.navigatedAwayFromProductsPage,
        SettingsPageActions.logoutClicked,
      ),
      tap(() => {
        productsService.unsubscribeFromOwnProducts();
      }),
    ),
  { dispatch: false, functional: true },
);

export const updateProduct$ = createEffect(
  (actions$ = inject(Actions), productsService = inject(ProductsService)) =>
    actions$.pipe(
      ofType(EditProductPageComponentActions.saveProductClicked),
      exhaustMap(({ exisitingProduct, changedProduct }) =>
        productsService
          .updateProduct({
            ...exisitingProduct,
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
