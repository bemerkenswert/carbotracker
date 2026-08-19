import { Routes } from '@angular/router';
import { ProductsPageComponent } from './pages/products-page/products-page.component';

const PRODUCTS_ROUTES: Routes = [
  {
    path: '',
    component: ProductsPageComponent,
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
