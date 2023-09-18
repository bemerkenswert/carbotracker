import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import * as productsEffects from './+state/products.effects';
import { productsFeature } from './+state/products.reducer';
import { ProductsPageComponent } from './pages/ProductsPage/products-page.component';

export const PRODUCTS_ROUTES: Routes = [
  {
    path: '',
    component: ProductsPageComponent,
    providers: [provideState(productsFeature), provideEffects(productsEffects)],
  },
  {
    path: 'create',
    loadComponent: () =>
      import('./pages/CreateProductPage/create-product-page.component'),
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./pages/EditProductPage/edit-product-page.component'),
  },
];
