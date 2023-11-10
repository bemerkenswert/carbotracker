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
      firstName: string;
      lastName: string;
      email: string;
      password: string;
    }>(),
    'Go Back Clicked': emptyProps(),
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
