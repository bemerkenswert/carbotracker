import { createActionGroup, emptyProps } from '@ngrx/store';

export const SettingsRouterEffectsActions = createActionGroup({
  source: 'Settings | Router Effects',
  events: {
    'Navigation to Account Page Successful': emptyProps(),
    'Navigation to Account Page Failed': emptyProps(),
    'Navigation to Change Password Page Successful': emptyProps(),
    'Navigation to Change Password Page Failed': emptyProps(),
    'Navigation to Insulin To Carb Ratios Page Successful': emptyProps(),
    'Navigation to Insulin To Carb Ratios Page Failed': emptyProps(),
  },
});
