import { Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { Store } from '@ngrx/store';
import { SettingsPageActions } from '../../+state';

@Component({
  selector: 'carbotracker-settings-page',
  standalone: true,
  imports: [MatButtonModule, MatIconModule, MatListModule],
  templateUrl: './settings-page.component.html',
  styleUrls: ['./settings-page.component.scss'],
})
export class SettingsPageComponent {
  private store = inject(Store);

  protected onLogout(): void {
    this.store.dispatch(SettingsPageActions.logoutClicked());
  }

  protected onAccount(): void {
    this.store.dispatch(SettingsPageActions.accountClicked());
  }
}
