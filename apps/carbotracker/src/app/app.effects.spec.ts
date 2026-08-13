import { Action, Store } from '@ngrx/store';
import { of, Subject } from 'rxjs';
import { LogoutApiActions } from '../features/auth/+state/actions/api.actions';
import { authFeature } from '../features/auth/+state/auth.store';
import { ThemePreferenceService } from '../features/settings/services/theme-preference.service';
import {
  startStreamingThemePreference$,
  stopStreamingThemePreference$,
} from './app.effects';
import { AuthApiActions } from '../features/auth/+state/actions/api.actions';

describe('startStreamingThemePreference', () => {
  const buildStore = (): Store =>
    ({
      select: jest.fn((selector) => {
        if (selector === authFeature.selectUserId) {
          return of('user-1');
        }
        return of(null);
      }),
    }) as unknown as Store;

  it('subscribes to the theme preference stream when the user logs in', () => {
    const themePreferenceService = {
      subscribeToOwnThemePreference: jest.fn(),
    } as unknown as ThemePreferenceService;

    const actions$ = new Subject<Action>();
    startStreamingThemePreference$(
      actions$.asObservable(),
      themePreferenceService,
      buildStore(),
    ).subscribe();

    actions$.next(
      AuthApiActions.userIsLoggedIn({ uid: 'user-1', email: 'a@b.c' }),
    );

    expect(
      themePreferenceService.subscribeToOwnThemePreference,
    ).toHaveBeenCalledWith({
      uid: 'user-1',
    });
  });
});

describe('stopStreamingThemePreference', () => {
  it('unsubscribes from the theme preference stream on logout', () => {
    const themePreferenceService = {
      unsubscribeFromOwnThemePreference: jest.fn(),
    } as unknown as ThemePreferenceService;

    const actions$ = new Subject<Action>();
    stopStreamingThemePreference$(
      actions$.asObservable(),
      themePreferenceService,
    ).subscribe();

    actions$.next(LogoutApiActions.logoutSuccessful());

    expect(
      themePreferenceService.unsubscribeFromOwnThemePreference,
    ).toHaveBeenCalled();
  });
});
