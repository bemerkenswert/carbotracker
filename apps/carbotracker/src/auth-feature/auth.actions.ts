import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { UserCredential } from 'firebase/auth';

export const AuthApiActions = createActionGroup({
  source: 'Auth | Auth Api',
  events: {
    'Login Successful': props<{ userCredential: UserCredential }>(),
    'Login Failed': props<{ error: unknown }>(),
    'User Is Logged In': props<{ uid: string }>(),
    'User Is Logged Out': emptyProps(),
  },
});