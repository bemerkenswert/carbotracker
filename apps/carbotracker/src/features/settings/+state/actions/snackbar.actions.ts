import { createActionGroup, emptyProps } from '@ngrx/store';

export const AccountPageSnackBarActions = createActionGroup({
  source: 'Settings | Account Page Snack Bar',
  events: {
    'Show Email Already Exists Snackbar Successful': emptyProps(),
    'Changes Successful Snackbar': emptyProps(),
  },
});

export const ChangePasswordPageSnackBarActions = createActionGroup({
  source: 'Settings | Change Password Page Snack Bar',
  events: {
    'Show Old Password Was Wrong Snackbar Successful': emptyProps(),
  },
});
