import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { InsulinToCarbRatio } from '../../insulin-to-carb-ratio.model';

export const SettingsApiActions = createActionGroup({
  source: 'Settings | Insulin To Carb Ratio Api',
  events: {
    'Updating Insulin To Carb Ratio Successful': emptyProps(),
    'Updating Insulin To Carb Ratio Failed': props<{ error: unknown }>(),
    'Creating Insulin To Carb Ratio Successful': emptyProps(),
    'Creating Insulin To Carb Ratio Failed': props<{ error: unknown }>(),
    'Insulin To Carb Ratio Collection Changed': props<{
      insulinToCarbRatios: InsulinToCarbRatio;
    }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Insulin To Carb Ratio Stream': emptyProps(),
  },
});
