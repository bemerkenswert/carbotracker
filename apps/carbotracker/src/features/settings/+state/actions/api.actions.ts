import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Factors } from '../../factors.model';

export const SettingsApiActions = createActionGroup({
  source: 'Settings | Factors Api',
  events: {
    'Updating Factors Successful': emptyProps(),
    'Updating Factors Failed': props<{ error: unknown }>(),
    'Creating Factors Successful': emptyProps(),
    'Creating Factors Failed': props<{ error: unknown }>(),
    'Factors Collection Changed': props<{ factors: Factors }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Factors Stream': emptyProps(),
  },
});
