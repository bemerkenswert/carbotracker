import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { AppRouterEffectsActions } from '../app/app.actions';
import { SignUpFormComponentActions } from '../login-feature/login.actions';
import { AuthApiActions } from './auth.actions';

interface AuthState {
  isInitialized: boolean;
  isLoggedIn: boolean;
  user: {
    uid: string | null;
    email: string | null;
  };
  error: string | null;
}

const getInitialState = (): AuthState => ({
  isInitialized: false,
  isLoggedIn: false,
  user: {
    uid: null,
    email: null,
  },
  error: null,
});

export const authFeature = createFeature({
  name: 'auth',
  extraSelectors: ({ selectUser, selectError }) => ({
    selectUserId: createSelector(selectUser, (user) => user.uid),
    selectError: createSelector(selectError, (error) => error),
    selectEmail: createSelector(selectUser, (user) =>
      user.email ? user.email : '',
    ),
  }),
  reducer: createReducer(
    getInitialState(),
    on(
      AuthApiActions.userIsLoggedIn,
      (state, { uid }): AuthState => ({
        ...state,
        isInitialized: true,
        isLoggedIn: true,
        user: {
          ...state.user,
          uid,
        },
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
      SignUpFormComponentActions.signUpFailedEmailExists,
      (state): AuthState => ({
        ...state,
        error: 'This email address already exists.',
      }),
    ),
    on(
      SignUpFormComponentActions.signUpFailedWeakPassword,
      (state): AuthState => ({
        ...state,
        error: 'This password is too weak, it should be at least 6 characters.',
      }),
    ),
    on(
      AppRouterEffectsActions.navigateToLoginPage,
      (state, { email }): AuthState => ({
        ...state,
        user: {
          ...state.user,
          email,
        },
      }),
    ),
  ),
});
