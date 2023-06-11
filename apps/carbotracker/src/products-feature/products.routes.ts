import { Routes } from '@angular/router';
import { ProductsPageComponent } from './pages/ProductsPage/products-page.component';
import { provideState } from '@ngrx/store';
import { productsFeature } from './+state/products.reducer';
import { provideEffects } from '@ngrx/effects';
import * as productsEffects from './+state/products.effects';

export const PRODUCTS_ROUTES: Routes = [
  {
    path: '',
    component: ProductsPageComponent,
    providers: [provideState(productsFeature), provideEffects(productsEffects)],
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./pages/EditProductPage/edit-product-page.component').then(
        (c) => c.EditProductPageComponent
      ),
  },
];
