import { TestBed } from '@angular/core/testing';
import { provideMockActions } from '@ngrx/effects/testing';
import { Action } from '@ngrx/store';
import { MockStore, provideMockStore } from '@ngrx/store/testing';
import { of, Subject, throwError } from 'rxjs';
import { take } from 'rxjs/operators';
import {
  AuthApiActions,
  LogoutApiActions,
} from '../../../auth/+state/actions/api.actions';
import { authFeature } from '../../../auth/+state/auth.store';
import { InsulinToCarbRatiosService } from '../../services/insulin-to-carb-ratios.service';
import { ThemePreferenceService } from '../../services/theme-preference.service';
import { SettingsApiActions } from '../actions/api.actions';
import {
  InsulinToCarbRatiosPageActions,
  SettingsPageActions,
} from '../actions/component.actions';
import {
  createInsulinToCarbRatios$,
  setThemePreference$,
  startStreamingInsulinToCarbRatios$,
  startStreamingThemePreference$,
  stopStreamingInsulinToCarbRatios$,
  stopStreamingThemePreference$,
} from './api.effects';

describe('createInsulinToCarbRatios', () => {
  let actions$: Subject<Action>;
  let insulinToCarbRatiosService: jest.Mocked<InsulinToCarbRatiosService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    insulinToCarbRatiosService = {
      setInsulinToCarbRatios: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<InsulinToCarbRatiosService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [{ selector: authFeature.selectUserId, value: 'user-1' }],
        }),
        {
          provide: InsulinToCarbRatiosService,
          useValue: insulinToCarbRatiosService,
        },
      ],
    });
  });

  it('writes the ratios and reports success when the user saves them', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      createInsulinToCarbRatios$().pipe(take(1)).subscribe((action) => results.push(action)),
    );

    actions$.next(
      InsulinToCarbRatiosPageActions.saveChangesClicked({
        insulinToCarbRatios: {
          showInsulinUnits: true,
          breakfast: 1,
          lunch: 2,
          dinner: 3,
          night: 4,
        },
      }),
    );

    expect(
      insulinToCarbRatiosService.setInsulinToCarbRatios,
    ).toHaveBeenCalledWith({
      insulinToCarbRatios: {
        showInsulinUnits: true,
        breakfast: 1,
        lunch: 2,
        dinner: 3,
        night: 4,
      },
      uid: 'user-1',
    });
    expect(results).toEqual([
      SettingsApiActions.settingInsulinToCarbRatiosSuccessful(),
    ]);
  });

  it('reports failure when writing the ratios fails', () => {
    insulinToCarbRatiosService.setInsulinToCarbRatios.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      createInsulinToCarbRatios$().pipe(take(1)).subscribe((action) => results.push(action)),
    );

    actions$.next(
      InsulinToCarbRatiosPageActions.saveChangesClicked({
        insulinToCarbRatios: {
          showInsulinUnits: true,
          breakfast: 1,
          lunch: 2,
          dinner: 3,
          night: 4,
        },
      }),
    );

    expect(results).toEqual([
      SettingsApiActions.settingInsulinToCarbRatiosFailed({
        error: expect.any(Error),
      }),
    ]);
  });
});

describe('setThemePreference', () => {
  let actions$: Subject<Action>;
  let themePreferenceService: jest.Mocked<ThemePreferenceService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    themePreferenceService = {
      setThemePreference: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<ThemePreferenceService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [{ selector: authFeature.selectUserId, value: 'user-1' }],
        }),
        { provide: ThemePreferenceService, useValue: themePreferenceService },
      ],
    });
  });

  it('writes the theme preference and reports success when the user changes the theme', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      setThemePreference$().pipe(take(1)).subscribe((action) => results.push(action)),
    );

    actions$.next(
      SettingsPageActions.themeChanged({ themePreference: 'dark' }),
    );

    expect(themePreferenceService.setThemePreference).toHaveBeenCalledWith({
      themePreference: 'dark',
      uid: 'user-1',
    });
    expect(results).toEqual([SettingsApiActions.settingThemeSuccessful()]);
  });

  it('reports failure when writing the theme preference fails', () => {
    themePreferenceService.setThemePreference.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      setThemePreference$().pipe(take(1)).subscribe((action) => results.push(action)),
    );

    actions$.next(
      SettingsPageActions.themeChanged({ themePreference: 'light' }),
    );

    expect(themePreferenceService.setThemePreference).toHaveBeenCalledWith({
      themePreference: 'light',
      uid: 'user-1',
    });
    expect(results).toEqual([
      SettingsApiActions.settingThemeFailed({ error: expect.any(Error) }),
    ]);
  });
});

describe('startStreamingInsulinToCarbRatios', () => {
  let actions$: Subject<Action>;
  let store: MockStore;
  let insulinToCarbRatiosService: jest.Mocked<InsulinToCarbRatiosService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    insulinToCarbRatiosService = {
      subscribeToOwnInsulinToCarbRatios: jest.fn(),
    } as unknown as jest.Mocked<InsulinToCarbRatiosService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [{ selector: authFeature.selectUserId, value: 'user-1' }],
        }),
        {
          provide: InsulinToCarbRatiosService,
          useValue: insulinToCarbRatiosService,
        },
      ],
    });

    store = TestBed.inject(MockStore);
  });

  it('subscribes to the insulin to carb ratios stream when the user logs in', () => {
    TestBed.runInInjectionContext(() => {
      startStreamingInsulinToCarbRatios$().pipe(take(1)).subscribe();
    });

    actions$.next(
      AuthApiActions.userIsLoggedIn({ uid: 'user-1', email: 'a@b.c' }),
    );

    expect(
      insulinToCarbRatiosService.subscribeToOwnInsulinToCarbRatios,
    ).toHaveBeenCalledWith({ uid: 'user-1' });
  });

  it('does not subscribe when the user id is not present', () => {
    store.overrideSelector(authFeature.selectUserId, null);
    TestBed.runInInjectionContext(() => {
      startStreamingInsulinToCarbRatios$().pipe(take(1)).subscribe();
    });

    actions$.next(
      AuthApiActions.userIsLoggedIn({ uid: 'user-1', email: 'a@b.c' }),
    );

    expect(
      insulinToCarbRatiosService.subscribeToOwnInsulinToCarbRatios,
    ).not.toHaveBeenCalled();
  });
});

describe('stopStreamingInsulinToCarbRatios', () => {
  let actions$: Subject<Action>;
  let insulinToCarbRatiosService: jest.Mocked<InsulinToCarbRatiosService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    insulinToCarbRatiosService = {
      unsubscribeFromOwnInsulinToCarbRatios: jest.fn(),
    } as unknown as jest.Mocked<InsulinToCarbRatiosService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore(),
        {
          provide: InsulinToCarbRatiosService,
          useValue: insulinToCarbRatiosService,
        },
      ],
    });
  });

  it('unsubscribes from the insulin to carb ratios stream on logout', () => {
    TestBed.runInInjectionContext(() => {
      stopStreamingInsulinToCarbRatios$().pipe(take(1)).subscribe();
    });

    actions$.next(LogoutApiActions.logoutSuccessful());

    expect(
      insulinToCarbRatiosService.unsubscribeFromOwnInsulinToCarbRatios,
    ).toHaveBeenCalled();
  });
});

describe('startStreamingThemePreference', () => {
  let actions$: Subject<Action>;
  let themePreferenceService: jest.Mocked<ThemePreferenceService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    themePreferenceService = {
      subscribeToOwnThemePreference: jest.fn(),
    } as unknown as jest.Mocked<ThemePreferenceService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [{ selector: authFeature.selectUserId, value: 'user-1' }],
        }),
        { provide: ThemePreferenceService, useValue: themePreferenceService },
      ],
    });
  });

  it('subscribes to the theme preference stream when the user logs in', () => {
    TestBed.runInInjectionContext(() => {
      startStreamingThemePreference$().pipe(take(1)).subscribe();
    });

    actions$.next(
      AuthApiActions.userIsLoggedIn({ uid: 'user-1', email: 'a@b.c' }),
    );

    expect(
      themePreferenceService.subscribeToOwnThemePreference,
    ).toHaveBeenCalledWith({ uid: 'user-1' });
  });
});

describe('stopStreamingThemePreference', () => {
  let actions$: Subject<Action>;
  let themePreferenceService: jest.Mocked<ThemePreferenceService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    themePreferenceService = {
      unsubscribeFromOwnThemePreference: jest.fn(),
    } as unknown as jest.Mocked<ThemePreferenceService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore(),
        { provide: ThemePreferenceService, useValue: themePreferenceService },
      ],
    });
  });

  it('unsubscribes from the theme preference stream on logout', () => {
    TestBed.runInInjectionContext(() => {
      stopStreamingThemePreference$().pipe(take(1)).subscribe();
    });

    actions$.next(LogoutApiActions.logoutSuccessful());

    expect(
      themePreferenceService.unsubscribeFromOwnThemePreference,
    ).toHaveBeenCalled();
  });
});
