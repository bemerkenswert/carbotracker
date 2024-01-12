import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { AccountPageComponent } from './pages/AccountPage/account-page.component';
import { SettingsPageComponent } from './pages/SettingsPage/settings-page.component';
import * as settingsEffects from './settings.effects';
import { ChangePasswordPageComponent } from './pages/ChangePasswordPage/ChangePasswordPage.component';

export const SETTINGS_ROUTES: Routes = [
  {
    path: '',
    providers: [provideEffects(settingsEffects)],
    children: [
      { path: '', pathMatch: 'full', component: SettingsPageComponent },
      { path: 'account', component: AccountPageComponent },
      { path: 'change-password', component: ChangePasswordPageComponent },
    ],
  },
];
