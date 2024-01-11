import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { SignUpSnackBarActions } from '../login-feature/login.actions';
import { SettingsApiActions } from '../settings-feature/settings.actions';
import { AuthApiActions } from './auth.actions';

interface AuthState {
  isInitialized: boolean;
  isLoggedIn: boolean;
  user: {
    uid: string | null;
    email: string | null;
  };
  alreadyExistingSignUpEmail: string | null;
}

const getInitialState = (): AuthState => ({
  isInitialized: false,
  isLoggedIn: false,
  user: {
    uid: null,
    email: null,
  },
  alreadyExistingSignUpEmail: null,
});

export const authFeature = createFeature({
  name: 'auth',
  extraSelectors: ({ selectUser }) => ({
    selectUserId: createSelector(selectUser, (user) => user.uid),
    selectEmail: createSelector(selectUser, (user) => user.email),
  }),
  reducer: createReducer(
    getInitialState(),
    on(
      SignUpSnackBarActions.goToLoginPageClicked,
      (state, { email }): AuthState => ({
        ...state,
        alreadyExistingSignUpEmail: email,
      }),
    ),
    on(
      AuthApiActions.userIsLoggedIn,
      (state, { uid, email }): AuthState => ({
        ...state,
        isInitialized: true,
        isLoggedIn: true,
        user: {
          ...state.user,
          uid,
          email,
        },
        alreadyExistingSignUpEmail: null,
      }),
    ),
    on(
      AuthApiActions.userIsLoggedOut,
      AuthApiActions.loginFailed,
      (state): AuthState => ({
        ...state,
        isInitialized: true,
        isLoggedIn: false,
        user: {
          ...state.user,
          uid: null,
        },
      }),
    ),
    on(
      SettingsApiActions.updateEmailSuccessful,
      (state, { email }): AuthState => ({
        ...state,
        user: {
          ...state.user,
          email: email,
        },
      }),
    ),
  ),
});
