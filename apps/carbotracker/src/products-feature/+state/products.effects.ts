import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, concatLatestFrom, createEffect, ofType } from '@ngrx/effects';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Store } from '@ngrx/store';
import {
  catchError,
  exhaustMap,
  filter,
  from,
  map,
  mergeMap,
  of,
  pipe,
  switchMap,
  tap,
} from 'rxjs';
import { authFeature } from '../../features/auth/+state/auth.store';
import { SettingsPageActions } from '../../features/settings/+state/actions/component.actions';
import { ProductsService } from '../services/products.service';
import {
  CreateProductPageComponentActions,
  EditProductPageComponentActions,
  ProductsApiActions,
  ProductsPageComponentActions,
  ProductsRouterActions,
} from './products.actions';

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

export const navigatedAwayFromProductsPage$ = createEffect(
  (actions$ = inject(Actions)) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(
        ({ payload }) =>
          !payload.event.urlAfterRedirects.startsWith('/app/products'),
      ),
      map(() => ProductsRouterActions.navigatedAwayFromProductsPage()),
    ),
  { dispatch: true, functional: true },
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

export const navigateToEditProduct$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ProductsPageComponentActions.productClicked),
      exhaustMap(({ product }) =>
        from(router.navigate(['app', 'products', product.id])),
      ),
    ),
  { dispatch: false, functional: true },
);

export const navigateToCreateProduct$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ProductsPageComponentActions.addClicked),
      exhaustMap(() => from(router.navigate(['app', 'products', 'create']))),
    ),
  { dispatch: false, functional: true },
);

export const navigateToProductsPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(
        ProductsApiActions.deletingProductSucceeded,
        ProductsApiActions.creatingProductSucceeded,
      ),
      exhaustMap(() => from(router.navigate(['app', 'products']))),
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
            map(() => ProductsApiActions.updatingProductSucceeded()),
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
      ofType(EditProductPageComponentActions.deleteClicked),
      exhaustMap(({ selectedProduct }) =>
        productsService.deleteProduct(selectedProduct).pipe(
          map(() => ProductsApiActions.deletingProductSucceeded()),
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
          map(() => ProductsApiActions.creatingProductSucceeded()),
          catchError((error) =>
            of(ProductsApiActions.creatingProductFailed(error)),
          ),
        ),
      ),
    ),
  { dispatch: true, functional: true },
);
