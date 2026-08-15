import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import {
  apiEffects,
  dialogEffects,
  productsFeature,
  routingEffects,
  snackbarEffects,
} from './+state';
import { ProductsPageComponent } from './pages/ProductsPage/products-page.component';

const PRODUCTS_ROUTES: Routes = [
  {
    path: '',
    component: ProductsPageComponent,
    providers: [
      provideState(productsFeature),
      provideEffects(
        apiEffects,
        routingEffects,
        snackbarEffects,
        dialogEffects,
      ),
    ],
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

export default PRODUCTS_ROUTES;
