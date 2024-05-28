import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Product } from '../../product.model';

export const ProductsApiActions = createActionGroup({
  source: 'Products | Products Api',
  events: {
    'Products Collection Changed': props<{ products: Product[] }>(),
    'Unsubscribed From Products Stream': emptyProps(),
    'Updating Product Successful': emptyProps(),
    'Updating Product Failed': props<{ error: unknown }>(),
    'Creating Product Successful': emptyProps(),
    'Creating Product Failed': props<{ error: unknown }>(),
    'Deleting Product Successful': emptyProps(),
    'Deleting Product Failed': props<{ error: unknown }>(),
  },
});
