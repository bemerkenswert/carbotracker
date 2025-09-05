import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { InsulinToCarbRatio } from '../../insulin-to-carb-ratio.model';

export const SettingsPageActions = createActionGroup({
  source: 'Settings | Settings Page',
  events: {
    'Logout Clicked': emptyProps(),
    'Account Clicked': emptyProps(),
    'Insulin To Carb Ratios Clicked': emptyProps(),
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

export const InsulinToCarbRatiosPageActions = createActionGroup({
  source: 'Settings | Insulin To Carb Ratios Page',
  events: {
    'Save Changes Clicked': props<{
      insulinToCarbRatios: Omit<InsulinToCarbRatio, 'creator'>;
    }>(),
    'Go Back Icon Clicked': emptyProps(),
  },
});
