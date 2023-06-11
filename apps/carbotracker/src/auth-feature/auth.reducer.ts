import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { AuthApiActions } from './auth.actions';

interface AuthState {
  isInitialized: boolean;
  isLoggedIn: boolean;
  user: {
    uid: string | null;
  };
}

const getInitialState = (): AuthState => ({
  isInitialized: false,
  isLoggedIn: false,
  user: {
    uid: null,
  },
});

export const authFeature = createFeature({
  name: 'auth',
  extraSelectors: ({ selectUser }) => ({
    selectUserId: createSelector(selectUser, (user) => user.uid),
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
      })
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
      })
    )
  ),
});
