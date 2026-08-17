import { DOCUMENT } from '@angular/common';
import { inject, Injectable } from '@angular/core';
import { Store } from '@ngrx/store';
import {
  combineLatest,
  fromEvent,
  map,
  Observable,
  shareReplay,
  startWith,
  tap,
} from 'rxjs';
import { ThemePreference } from '../features/settings/theme-preference.model';
import { settingsFeature } from '../features/settings/+state/settings.store';

export type ResolvedTheme = 'light' | 'dark';

const DARK_THEME_CLASS = 'dark-theme';
const PREFERS_COLOR_SCHEME_DARK = '(prefers-color-scheme: dark)';

const resolveTheme = (
  themePreference: ThemePreference,
  systemPrefersDark: boolean,
): ResolvedTheme => {
  if (themePreference === 'light') {
    return 'light';
  }
  if (themePreference === 'dark') {
    return 'dark';
  }
  return systemPrefersDark ? 'dark' : 'light';
};

@Injectable({ providedIn: 'root' })
export class ThemeApplicationService {
  private readonly document = inject(DOCUMENT);
  private readonly store = inject(Store);
  private readonly systemPrefersDark$ = this.createSystemPrefersDark$();

  readonly resolvedTheme$: Observable<ResolvedTheme> = combineLatest([
    this.store.select(settingsFeature.selectThemePreference),
    this.systemPrefersDark$,
  ]).pipe(
    map(([themePreference, systemPrefersDark]) =>
      resolveTheme(themePreference, systemPrefersDark),
    ),
    shareReplay({ bufferSize: 1, refCount: true }),
  );

  constructor() {
    this.resolvedTheme$
      .pipe(
        tap((theme) => {
          this.document.documentElement.classList.toggle(
            DARK_THEME_CLASS,
            theme === 'dark',
          );
        }),
      )
      .subscribe();
  }

  private createSystemPrefersDark$(): Observable<boolean> {
    const mediaQueryList = window.matchMedia(PREFERS_COLOR_SCHEME_DARK);
    return fromEvent<MediaQueryListEvent>(mediaQueryList, 'change').pipe(
      map((event) => event.matches),
      startWith(mediaQueryList.matches),
    );
  }
}
