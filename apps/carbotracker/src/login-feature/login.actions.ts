import { createActionGroup, emptyProps, props } from '@ngrx/store';

export const LoginFormComponentActions = createActionGroup({
  source: 'Login | Login Form Component',
  events: {
    'Login Clicked': props<{ email: string; password: string }>(),
    'Sign Up Clicked': emptyProps(),
  },
});

export const SignUpFormComponentActions = createActionGroup({
  source: 'Login | Sign Up Form Component',
  events: {
    'Sign Up Clicked': props<{
      email: string;
      password: string;
    }>(),
    'Go Back Clicked': emptyProps(),
  },
});
export const SignUpApiActions = createActionGroup({
  source: 'Login | Sign Up Api',
  events: {
    'Sign Up Successful': emptyProps(),
    'Sign Up Failed Email Exists': props<{ email: string }>(),
    'Sign Up Failed Weak Password': emptyProps(),
    'Sign Up Failed Unknown Error': emptyProps(),
  },
});

export const SignUpSnackBarActions = createActionGroup({
  source: 'Login | Sign Up Snack Bar',
  events: {
    'Show Email Already Exists Snackbar Successful': emptyProps(),
    'Show Password Is Weak Snackbar Successful': emptyProps(),
    'Go to Login Page Clicked': props<{ email: string }>(),
  },
});

export const RoutingActions = createActionGroup({
  source: 'Login | Routing',
  events: {
    'Navigation to Login Page Successful': emptyProps(),
    'Navigation to Login Page Failed': emptyProps(),
    'Navigation to Sign Up Page Successful': emptyProps(),
    'Navigation to Sign Up Page Failed': emptyProps(),
  },
});
