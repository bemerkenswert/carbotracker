import { createActionGroup, emptyProps } from '@ngrx/store';

export const EditProductPageSnackBarActions = createActionGroup({
  source: 'Products | Edit Product Page Snack Bar',
  events: {
    'Show Edit Product Snackbar Successful': emptyProps(),
  },
});
