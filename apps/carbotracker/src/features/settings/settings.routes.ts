import { Routes } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideState } from '@ngrx/store';
import { routingEffects, snackbarEffects } from './+state';
import { factorsFeature } from './+state/factors.reducer';
import { AccountPageComponent } from './pages/account-page/account-page.component';
import { ChangePasswordPageComponent } from './pages/change-password-page/change-password-page.component';
import { FactorsPageComponent } from './pages/factors-page/factors-page.component';
import { SettingsPageComponent } from './pages/settings-page/settings-page.component';

const SETTINGS_ROUTES: Routes = [
  {
    path: '',
    providers: [
      provideEffects(routingEffects, snackbarEffects),
      provideState(factorsFeature),
    ],
    children: [
      { path: '', pathMatch: 'full', component: SettingsPageComponent },
      { path: 'account', component: AccountPageComponent },
      { path: 'change-password', component: ChangePasswordPageComponent },
      { path: 'factors', component: FactorsPageComponent },
    ],
  },
];

export default SETTINGS_ROUTES;
