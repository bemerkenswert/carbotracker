import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { InsulinToCarbRatio } from '../../insulin-to-carb-ratio.model';
import { ThemePreference } from '../../theme-preference.model';

export const SettingsApiActions = createActionGroup({
  source: 'Settings | Api',
  events: {
    'Setting Insulin To Carb Ratios Successful': emptyProps(),
    'Setting Insulin To Carb Ratios Failed': props<{ error: unknown }>(),
    'Insulin To Carb Ratios Collection Changed': props<{
      insulinToCarbRatios: InsulinToCarbRatio;
    }>(),
    'Setting Theme Successful': emptyProps(),
    'Setting Theme Failed': props<{ error: unknown }>(),
    'Theme Collection Changed': props<{ themePreference: ThemePreference }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Insulin To Carb Ratios Stream': emptyProps(),
    'Unsubscribed From Theme Stream': emptyProps(),
  },
});
