import { Action, Store } from '@ngrx/store';
import { of, Subject, throwError } from 'rxjs';
import { authFeature } from '../../../auth/+state/auth.store';
import { ThemePreferenceService } from '../../services/theme-preference.service';
import { SettingsApiActions } from '../actions/api.actions';
import { SettingsPageActions } from '../actions/component.actions';
import { setThemePreference$ } from './api.effects';

describe('setThemePreference', () => {
  const buildStore = (): Store =>
    ({
      select: jest.fn((selector) => {
        if (selector === authFeature.selectUserId) {
          return of('user-1');
        }
        return of(null);
      }),
    }) as unknown as Store;

  it('writes the theme preference and reports success when the user changes the theme', () => {
    const themePreferenceService = {
      setThemePreference: jest.fn(() => of(undefined)),
    } as unknown as ThemePreferenceService;

    const actions$ = new Subject<Action>();
    const emitted: Action[] = [];
    setThemePreference$(
      actions$.asObservable(),
      buildStore(),
      themePreferenceService,
    ).subscribe((action) => emitted.push(action));

    actions$.next(
      SettingsPageActions.themeChanged({ themePreference: 'dark' }),
    );

    expect(themePreferenceService.setThemePreference).toHaveBeenCalledWith({
      themePreference: 'dark',
      uid: 'user-1',
    });
    expect(emitted).toEqual([SettingsApiActions.settingThemeSuccessful()]);
  });

  it('reports failure when writing the theme preference fails', () => {
    const themePreferenceService = {
      setThemePreference: jest.fn(() => throwError(() => new Error('boom'))),
    } as unknown as ThemePreferenceService;

    const actions$ = new Subject<Action>();
    const emitted: Action[] = [];
    setThemePreference$(
      actions$.asObservable(),
      buildStore(),
      themePreferenceService,
    ).subscribe((action) => emitted.push(action));

    actions$.next(
      SettingsPageActions.themeChanged({ themePreference: 'light' }),
    );

    expect(themePreferenceService.setThemePreference).toHaveBeenCalledWith({
      themePreference: 'light',
      uid: 'user-1',
    });
    expect(emitted).toEqual([
      SettingsApiActions.settingThemeFailed({ error: new Error('boom') }),
    ]);
  });
});
