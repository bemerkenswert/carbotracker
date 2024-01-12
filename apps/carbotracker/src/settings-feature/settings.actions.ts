import { createActionGroup, emptyProps, props } from '@ngrx/store';

export const SettingsRouterEffectsActions = createActionGroup({
  source: 'Settings | Router Effects',
  events: {
    'Navigation to Account Page Successful': emptyProps(),
    'Navigation to Account Page Failed': emptyProps(),
    'Navigation to Change Password Page Successful': emptyProps(),
    'Navigation to Change Password Page Failed': emptyProps(),
  },
});

export const SettingsPageActions = createActionGroup({
  source: 'Settings | Settings Page',
  events: {
    'Logout Clicked': emptyProps(),
    'Account Clicked': emptyProps(),
  },
});

export const ChangePasswordPageActions = createActionGroup({
  source: 'Settings | Change Password Page',
  events: {
    'Change Password Clicked': props<{
      oldPassword: string;
      newPassword: string;
      confirmPassword: string;
    }>(),
  },
});

export const SettingsApiActions = createActionGroup({
  source: 'Settings | Settings Page API',
  events: {
    'Update Email Successful': props<{ email: string }>(),
    'Update Email Failed': props<{ error: unknown }>(),
    'Update Email Failed Email Exists': emptyProps(),
    'Update Password Successful': emptyProps(),
    'Update Password Failed': props<{ error: unknown }>(),
    'Update Password Failed Weak Password': emptyProps(),
  },
});

export const AccountPageSnackBarActions = createActionGroup({
  source: 'Settings | Account Page Snack Bar',
  events: {
    'Show Email Already Exists Snackbar Successful': emptyProps(),
    'Changes Successful Snackbar': emptyProps(),
  },
});

export const AccountPageActions = createActionGroup({
  source: 'Settings | Account Page',
  events: {
    'Save Changes Clicked': props<{ email: string }>(),
    'Password Input Focused': emptyProps(),
  },
});
