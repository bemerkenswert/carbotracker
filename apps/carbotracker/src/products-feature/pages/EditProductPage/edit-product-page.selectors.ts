import { createSelector } from '@ngrx/store';
import { productsFeature } from '../../+state/products.reducer';
import { Product } from '../../product.model';

export interface EditProductPageViewModel {
  product: Product | null;
  pageTitle: string;
  initialFormValues: Pick<Product, 'name' | 'carbs'> | null;
}

export const selectEditProductPageViewModel = createSelector(
  productsFeature.selectCurrentProduct,
  (product): EditProductPageViewModel => ({
    product,
    pageTitle: 'Edit product',
    initialFormValues: product
      ? { name: product.name, carbs: product.carbs }
      : null,
  }),
);
