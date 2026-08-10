import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { MealLogDocument } from '../meal-log.model';

export const HistoryPageComponentActions = createActionGroup({
  source: 'Meal Logs | History Page Component',
  events: {
    'Entered History Page': emptyProps(),
    'Left History Page': emptyProps(),
    'Date Selected': props<{ date: string }>(),
    'Log Insulin Dose Clicked': emptyProps(),
  },
});

export const MealLogsApiActions = createActionGroup({
  source: 'Meal Logs | Meal Logs Api',
  events: {
    'Meal Logs Collection Changed': props<{ mealLogs: MealLogDocument[] }>(),
    'Insulin Dose Created': emptyProps(),
    'Insulin Dose Creation Failed': props<{ error: unknown }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Meal Logs Stream': emptyProps(),
  },
});
