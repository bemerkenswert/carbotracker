import { TestBed } from '@angular/core/testing';
import { Store } from '@ngrx/store';
import { BehaviorSubject, of } from 'rxjs';
import { ThemePreference } from '../features/settings/theme-preference.model';
import { settingsFeature } from './app.reducer';
import { ThemeApplicationService } from './theme-application.service';

const DARK_THEME_CLASS = 'dark-theme';

describe('ThemeApplicationService', () => {
  const buildStore = () => {
    const themePreference$ = new BehaviorSubject<ThemePreference>('system');
    const store = {
      select: jest.fn((selector) => {
        if (selector === settingsFeature.selectThemePreference) {
          return themePreference$;
        }
        return of(null);
      }),
    } as unknown as Store;
    return { store, themePreference$ };
  };

  const createMatchMediaMock = () => {
    let currentMatches = false;
    const listeners = new Set<(event: MediaQueryListEvent) => void>();
    const query = {
      get matches() {
        return currentMatches;
      },
      addEventListener: (
        _type: string,
        listener: (event: MediaQueryListEvent) => void,
      ) => listeners.add(listener),
      removeEventListener: jest.fn(),
    };
    window.matchMedia = jest.fn().mockReturnValue(query);
    return {
      setMatches: (matches: boolean) => {
        currentMatches = matches;
        listeners.forEach((listener) =>
          listener({ matches } as MediaQueryListEvent),
        );
      },
    };
  };

  const getService = (store: Store) => {
    TestBed.configureTestingModule({
      providers: [{ provide: Store, useValue: store }],
    });
    return TestBed.inject(ThemeApplicationService);
  };

  beforeEach(() => {
    document.documentElement.classList.remove(DARK_THEME_CLASS);
  });

  it('applies the dark class when the system prefers dark and the stored preference is system', () => {
    createMatchMediaMock().setMatches(true);
    const { store } = buildStore();

    getService(store);

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(true);
  });

  it('does not apply the dark class when the system prefers light and the stored preference is system', () => {
    createMatchMediaMock().setMatches(false);
    const { store } = buildStore();

    getService(store);

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(false);
  });

  it('applies the dark class when the stored preference is dark', () => {
    createMatchMediaMock().setMatches(false);
    const { store, themePreference$ } = buildStore();
    themePreference$.next('dark');

    getService(store);

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(true);
  });

  it('does not apply the dark class when the stored preference is light', () => {
    createMatchMediaMock().setMatches(true);
    const { store, themePreference$ } = buildStore();
    themePreference$.next('light');

    getService(store);

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(false);
  });

  it('updates the class when the system preference changes while the stored preference is system', () => {
    const matchMedia = createMatchMediaMock();
    matchMedia.setMatches(false);
    const { store } = buildStore();

    getService(store);

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(false);

    matchMedia.setMatches(true);

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(true);
  });

  it('keeps the dark class when the system preference changes while the stored preference is dark', () => {
    const matchMedia = createMatchMediaMock();
    matchMedia.setMatches(false);
    const { store, themePreference$ } = buildStore();
    themePreference$.next('dark');

    getService(store);

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(true);

    matchMedia.setMatches(true);

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(true);
  });

  it('updates the class when the stored preference changes to dark', () => {
    createMatchMediaMock().setMatches(false);
    const { store, themePreference$ } = buildStore();

    getService(store);

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(false);

    themePreference$.next('dark');

    expect(
      document.documentElement.classList.contains(DARK_THEME_CLASS),
    ).toBe(true);
  });
});
