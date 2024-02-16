import { createActionGroup, emptyProps, props } from '@ngrx/store';

export const SignUpSnackBarActions = createActionGroup({
  source: 'Auth | Sign Up Snack Bar',
  events: {
    'Show Email Already Exists Snackbar Successful': emptyProps(),
    'Show Password Is Weak Snackbar Successful': emptyProps(),
    'Go to Login Page Clicked': props<{ email: string }>(),
  },
});

export const LoginSnackBarActions = createActionGroup({
  source: 'Auth | Login Snack Bar',
  events: {
    'Show Password Is Wrong Snackbar Successful': emptyProps(),
  },
});
