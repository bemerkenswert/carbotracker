import { Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { CtuiToolbarComponent } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { ThemePreferenceService } from '../../../../app/theme-preference.service';
import { SettingsPageActions } from '../../+state';

interface SettingsItem {
  onClick: () => void;
  icon: string;
  name: string;
}

const getSettingsItems = (): SettingsItem[] => {
  const store = inject(Store);
  return [
    {
      onClick: () => store.dispatch(SettingsPageActions.accountClicked()),
      icon: 'person',
      name: 'Account',
    },
    {
      onClick: () =>
        store.dispatch(SettingsPageActions.insulinToCarbRatiosClicked()),
      icon: 'edit_attributes',
      name: 'Insulin to carb ratios',
    },
    {
      onClick: () => store.dispatch(SettingsPageActions.logoutClicked()),
      icon: 'logout',
      name: 'Logout',
    },
  ];
};

@Component({
  selector: 'carbotracker-settings-page',
  imports: [
    MatButtonModule,
    MatIconModule,
    MatListModule,
    MatSlideToggleModule,
    CtuiToolbarComponent,
  ],
  templateUrl: './settings-page.component.html',
  styleUrls: ['./settings-page.component.scss'],
})
export class SettingsPageComponent {
  protected readonly settingsItems: SettingsItem[] = getSettingsItems();
  private readonly themePreferenceService = inject(ThemePreferenceService);
  protected readonly isDarkMode = this.themePreferenceService.isDarkMode();

  protected onDarkModeChanged(isDarkMode: boolean): void {
    this.themePreferenceService.setDarkMode(isDarkMode);
  }
}
