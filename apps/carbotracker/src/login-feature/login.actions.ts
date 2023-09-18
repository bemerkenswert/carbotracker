import { createActionGroup, props } from '@ngrx/store';

export const LoginFormComponentActions = createActionGroup({
  source: 'Login | Login Form Component',
  events: {
    'Login Clicked': props<{ email: string; password: string }>(),
  },
});
