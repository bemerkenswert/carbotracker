import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { apiEffects, routingEffects, snackbarEffects } from './+state';
import { AccountPageComponent } from './pages/account-page/account-page.component';
import { ChangePasswordPageComponent } from './pages/change-password-page/change-password-page.component';
import { InsulinToCarbRatiosPageComponent } from './pages/insulin-to-carb-ratios-page/insulin-to-carb-ratios-page.component';
import { SettingsPageComponent } from './pages/settings-page/settings-page.component';

const SETTINGS_ROUTES: Routes = [
  {
    path: '',
    providers: [provideEffects(apiEffects, routingEffects, snackbarEffects)],
    children: [
      { path: '', pathMatch: 'full', component: SettingsPageComponent },
      { path: 'account', component: AccountPageComponent },
      { path: 'change-password', component: ChangePasswordPageComponent },
      {
        path: 'insulin-to-carb-ratios',
        component: InsulinToCarbRatiosPageComponent,
      },
    ],
  },
];

export default SETTINGS_ROUTES;
