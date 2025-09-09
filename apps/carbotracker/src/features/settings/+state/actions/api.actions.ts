import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { InsulinToCarbRatio } from '../../insulin-to-carb-ratio.model';

export const SettingsApiActions = createActionGroup({
  source: 'Settings | Insulin To Carb Ratios Api',
  events: {
    'Setting Insulin To Carb Ratios Successful': emptyProps(),
    'Setting Insulin To Carb Ratios Failed': props<{ error: unknown }>(),
    'Insulin To Carb Ratios Collection Changed': props<{
      insulinToCarbRatios: InsulinToCarbRatio;
    }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Insulin To Carb Ratios Stream': emptyProps(),
  },
});
