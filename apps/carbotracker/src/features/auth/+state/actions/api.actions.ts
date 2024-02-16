import { createActionGroup, props, emptyProps } from '@ngrx/store';
import { UserCredential } from 'firebase/auth';

export const LoginApiActions = createActionGroup({
  source: 'Auth | Login Api',
  events: {
    'Login Successful': props<{ userCredential: UserCredential }>(),
    'Login Failed': props<{ error: unknown }>(),
    'Login Failed Wrong Password': emptyProps(),
    'Reauthenticate Failed Wrong Password': emptyProps(),
    'Reauthenticate Failed': props<{ error: unknown }>(),
  },
});

export const LogoutApiActions = createActionGroup({
  source: 'Auth | Logout Api',
  events: {
    'Logout Successful': emptyProps(),
    'Logout Failed': props<{ error: unknown }>(),
  },
});

export const AuthApiActions = createActionGroup({
  source: 'Auth | Auth Api',
  events: {
    'User Is Logged In': props<{ uid: string; email: string }>(),
    'User Is Logged Out': emptyProps(),
  },
});

export const SignUpApiActions = createActionGroup({
  source: 'Auth | Sign Up Api',
  events: {
    'Sign Up Successful': emptyProps(),
    'Sign Up Failed Email Exists': props<{ email: string }>(),
    'Sign Up Failed Weak Password': emptyProps(),
    'Sign Up Failed Unknown Error': emptyProps(),
  },
});

export const EmailApiActions = createActionGroup({
  source: 'Auth | Email Api',
  events: {
    'Update Email Successful': props<{ email: string }>(),
    'Update Email Failed': props<{ error: unknown }>(),
    'Update Email Failed Email Exists': emptyProps(),
  },
});

export const PasswordApiActions = createActionGroup({
  source: 'Settings | Password Api',
  events: {
    'Update Password Successful': emptyProps(),
    'Update Password Failed': props<{ error: unknown }>(),
    'Update Password Failed Weak Password': emptyProps(),
  },
});
