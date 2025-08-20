import { Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { CtuiToolbarComponent } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
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
        CtuiToolbarComponent,
    ],
    templateUrl: './settings-page.component.html',
    styleUrls: ['./settings-page.component.scss']
})
export class SettingsPageComponent {
  protected readonly settingsItems: SettingsItem[] = getSettingsItems();
}
