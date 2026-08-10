import { DOCUMENT } from '@angular/common';
import { inject, Injectable, signal } from '@angular/core';

const DARK_MODE_STORAGE_KEY = 'carbotracker.darkMode';
const DARK_THEME_CLASS = 'dark-theme';

@Injectable({ providedIn: 'root' })
export class ThemePreferenceService {
  private readonly document = inject(DOCUMENT);
  private readonly darkMode = signal(this.getStoredDarkModePreference());

  constructor() {
    this.applyDarkModePreference(this.darkMode());
  }

  public isDarkMode() {
    return this.darkMode.asReadonly();
  }

  public setDarkMode(isDarkMode: boolean): void {
    this.darkMode.set(isDarkMode);
    this.storeDarkModePreference(isDarkMode);
    this.applyDarkModePreference(isDarkMode);
  }

  private applyDarkModePreference(isDarkMode: boolean): void {
    this.document.documentElement.classList.toggle(
      DARK_THEME_CLASS,
      isDarkMode,
    );
  }

  private getStoredDarkModePreference(): boolean {
    try {
      return localStorage.getItem(DARK_MODE_STORAGE_KEY) === 'true';
    } catch {
      return false;
    }
  }

  private storeDarkModePreference(isDarkMode: boolean): void {
    try {
      localStorage.setItem(DARK_MODE_STORAGE_KEY, String(isDarkMode));
    } catch {
      // Ignore unavailable storage; the class still applies for this session.
    }
  }
}
