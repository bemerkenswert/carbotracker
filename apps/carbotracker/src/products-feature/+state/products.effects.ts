import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Store } from '@ngrx/store';
import {
  catchError,
  exhaustMap,
  filter,
  from,
  map,
  of,
  switchMap,
  tap,
} from 'rxjs';
import { authFeature } from '../../auth-feature/auth.reducer';
import { ProductsService } from '../services/products.service';
import {
  EditProductPageComponentActions,
  ProductsApiActions,
  ProductsPageComponentActions,
} from './products.actions';

export const startStreamingProducts$ = createEffect(
  (
    actions$ = inject(Actions),
    productsService = inject(ProductsService),
    store = inject(Store)
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(({ payload }) =>
        payload.event.urlAfterRedirects.startsWith('/app/products')
      ),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          productsService.subscribeToOwnProducts({ uid });
        }
      })
    ),
  { dispatch: false, functional: true }
);

export const stopStreamingProducts$ = createEffect(
  (actions$ = inject(Actions), productsService = inject(ProductsService)) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(
        ({ payload }) =>
          !payload.event.urlAfterRedirects.startsWith('/app/products')
      ),
      tap(() => {
        productsService.unsubscribeFromOwnProducts();
      })
    ),
  { dispatch: false, functional: true }
);

export const navigateToEditProduct$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(ProductsPageComponentActions.productClicked),
      exhaustMap(({ product }) =>
        from(router.navigate(['app', 'products', product.id]))
      )
    ),
  { dispatch: false, functional: true }
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
            catchError(() => of(ProductsApiActions.updatingProductFailed()))
          )
      )
    ),
  { dispatch: true, functional: true }
);
