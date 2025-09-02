import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Factors } from '../../factors.model';

export const SettingsPageActions = createActionGroup({
  source: 'Settings | Settings Page',
  events: {
    'Logout Clicked': emptyProps(),
    'Account Clicked': emptyProps(),
    'Factors Clicked': emptyProps(),
  },
});

export const ChangePasswordPageActions = createActionGroup({
  source: 'Settings | Change Password Page',
  events: {
    'Change Password Clicked': props<{
      oldPassword: string;
      newPassword: string;
    }>(),
    'Go Back Icon Clicked': emptyProps(),
  },
});

export const AccountPageActions = createActionGroup({
  source: 'Settings | Account Page',
  events: {
    'Save Changes Clicked': props<{ email: string }>(),
    'Password Input Focused': emptyProps(),
    'Go Back Icon Clicked': emptyProps(),
  },
});

export const FactorsPageActions = createActionGroup({
  source: 'Settings | Factors Page',
  events: {
    'Save Changes Clicked': props<{ factors: Omit<Factors, 'creator'> }>(),
    'Go Back Icon Clicked': emptyProps(),
  },
});
