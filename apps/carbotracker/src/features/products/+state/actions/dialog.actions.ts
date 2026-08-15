import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Product } from '../../product.model';

export const DeleteProductConfirmationDialogActions = createActionGroup({
  source: 'Products | Delete Product Confirmation Dialog',
  events: {
    'Confirm Clicked': props<{
      selectedProduct: Product;
    }>(),
    'Abort Clicked': emptyProps(),
  },
});
