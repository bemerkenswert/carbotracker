import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Product } from '../product.model';

export const ProductsPageComponentActions = createActionGroup({
  source: 'Products | Products Page Component',
  events: {
    'Entered Products Page': emptyProps(),
    'Left Products Page': emptyProps(),
    'Product Clicked': props<{ product: Product }>(),
    'Add Clicked': emptyProps(),
  },
});

export const EditProductPageComponentActions = createActionGroup({
  source: 'Products | Edit Product Page Component',
  events: {
    'Selected Product Changed': props<{ selectedProduct: string }>(),
    'Save Product Clicked': props<{
      exisitingProduct: Product;
      changedProduct: Pick<Product, 'name' | 'carbs'>;
    }>(),
  },
});

export const ProductsApiActions = createActionGroup({
  source: 'Products | Products Api',
  events: {
    'Products Collection Changed': props<{ products: Product[] }>(),
    'Unsubscribed From Products Stream': emptyProps(),
    'Updating Product Succeeded': emptyProps(),
    'Updating Product Failed': emptyProps(),
  },
});
