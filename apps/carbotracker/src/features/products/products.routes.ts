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
import { ProductsPageComponent } from './pages/products-page/products-page.component';

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
      import('./pages/create-product-page/create-product-page.component'),
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./pages/edit-product-page/edit-product-page.component'),
  },
];

export default PRODUCTS_ROUTES;
