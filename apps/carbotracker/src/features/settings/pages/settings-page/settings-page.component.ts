import { Component, inject } from '@angular/core';
import { AsyncPipe } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { CtuiToolbarComponent } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { map, Observable } from 'rxjs';
import { ThemeApplicationService } from '../../../../app/theme-application.service';
import { SettingsPageActions } from '../../+state';

interface SettingsItem {
  onClick?: () => void;
  icon: string;
  name: string;
  checked$?: Observable<boolean>;
  onToggle?: (checked: boolean) => void;
}

const getSettingsItems = (): SettingsItem[] => {
  const store = inject(Store);
  const themeApplicationService = inject(ThemeApplicationService);
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
      icon: 'dark_mode',
      name: 'Dark theme',
      checked$: themeApplicationService.resolvedTheme$.pipe(
        map((theme) => theme === 'dark'),
      ),
      onToggle: (checked) =>
        store.dispatch(
          SettingsPageActions.themeChanged({
            themePreference: checked ? 'dark' : 'light',
          }),
        ),
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
    AsyncPipe,
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
}
