import { createActionGroup, emptyProps, props } from '@ngrx/store';

export const SettingsApiActions = createActionGroup({
  source: 'Settings | Factors Api',
  events: {
    'Updating Factors Successful': emptyProps(),
    'Updating Factors Failed': props<{ error: unknown }>(),
    'Creating Factors Successful': emptyProps(),
    'Creating Factors Failed': props<{ error: unknown }>(),
  },
});
