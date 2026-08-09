import { createActionGroup, emptyProps } from '@ngrx/store';

export const CreateProductPageSnackBarActions = createActionGroup({
  source: 'Products | Create Product Page Snack Bar',
  events: {
    'Show Create Product Snackbar Successful': emptyProps(),
    'Show Create Product Snackbar Failure': emptyProps(),
  },
});

export const EditProductPageSnackBarActions = createActionGroup({
  source: 'Products | Edit Product Page Snack Bar',
  events: {
    'Show Edit Product Snackbar Successful': emptyProps(),
    'Show Edit Product Snackbar Failure': emptyProps(),
  },
});

export const DeleteProductSnackBarActions = createActionGroup({
  source: 'Products | Delete Product Snack Bar',
  events: {
    'Show Delete Product Snackbar Successful': emptyProps(),
    'Show Delete Product Snackbar Failure': emptyProps(),
  },
});
