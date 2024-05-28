import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { routerNavigatedAction } from '@ngrx/router-store';
import { exhaustMap, filter, from, map } from 'rxjs';
import { ProductsApiActions } from '../actions/api.actions';
import {
  CreateProductPageComponentActions,
  EditProductPageComponentActions,
  ProductsPageComponentActions,
} from '../actions/component.actions';
import { ProductsRouterActions } from '../actions/routing.actions';

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
        ProductsApiActions.deletingProductSuccessful,
        ProductsApiActions.creatingProductSuccessful,
        ProductsApiActions.updatingProductSuccessful,
        CreateProductPageComponentActions.goBackIconClicked,
        EditProductPageComponentActions.goBackIconClicked,
      ),
      exhaustMap(() => from(router.navigate(['app', 'products']))),
    ),
  { dispatch: false, functional: true },
);
