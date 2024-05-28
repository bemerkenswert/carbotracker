import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Product } from '../../product.model';

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
    'Delete Clicked': props<{ selectedProduct: string }>(),
    'Go Back Icon Clicked': emptyProps(),
  },
});

export const CreateProductPageComponentActions = createActionGroup({
  source: 'Products | Create Product Page Component',
  events: {
    'Save Product Clicked': props<{
      newProduct: Pick<Product, 'name' | 'carbs'>;
    }>(),
    'Go Back Icon Clicked': emptyProps(),
  },
});
