import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { exhaustMap, from } from 'rxjs';
import { ProductsApiActions } from '../actions/api.actions';
import {
  CreateProductPageComponentActions,
  EditProductPageComponentActions,
  ProductsPageComponentActions,
} from '../actions/component.actions';

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
