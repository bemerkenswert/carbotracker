import { createActionGroup, props, emptyProps } from '@ngrx/store';

export const LoginFormComponentActions = createActionGroup({
  source: 'Auth | Login Form Component',
  events: {
    'Login Clicked': props<{ email: string; password: string }>(),
    'Sign Up Clicked': emptyProps(),
  },
});

export const SignUpFormComponentActions = createActionGroup({
  source: 'Auth | Sign Up Form Component',
  events: {
    'Sign Up Clicked': props<{
      email: string;
      password: string;
    }>(),
    'Go Back Clicked': emptyProps(),
  },
});
