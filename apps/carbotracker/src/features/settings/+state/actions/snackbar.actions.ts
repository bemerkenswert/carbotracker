import { createActionGroup, emptyProps } from '@ngrx/store';

export const AccountPageSnackBarActions = createActionGroup({
  source: 'Settings | Account Page Snack Bar',
  events: {
    'Show Email Already Exists Snackbar Successful': emptyProps(),
    'Changes Successful Snackbar': emptyProps(),
  },
});
