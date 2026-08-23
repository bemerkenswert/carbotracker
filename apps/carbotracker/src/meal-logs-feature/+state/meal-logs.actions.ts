import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { MealLogDocument } from '../meal-log.model';
import { ConfirmedSportDialogResult } from '../sport-dialog/sport-dialog.model';

export const HistoryPageComponentActions = createActionGroup({
  source: 'Meal Logs | History Page Component',
  events: {
    'Entered History Page': emptyProps(),
    'Left History Page': emptyProps(),
    'Date Selected': props<{ date: string }>(),
    'Log Insulin Dose Clicked': emptyProps(),
    'Log Sport Clicked': emptyProps(),
    'Edit Insulin Dose Clicked': props<{ mealLog: MealLogDocument }>(),
    'Edit Meal Log Clicked': props<{ mealLog: MealLogDocument }>(),
    'Delete Meal Log Document Clicked': props<{ mealLog: MealLogDocument }>(),
    'Reload Meal Log Into Meal Clicked': props<{ mealLog: MealLogDocument }>(),
  },
});

export const SportLogDialogActions = createActionGroup({
  source: 'Meal Logs | Sport Log Dialog',
  events: {
    'Sport Log Confirmed': props<{
      uid: string;
      result: ConfirmedSportDialogResult;
    }>(),
    'Sport Saved To Catalog': emptyProps(),
    'Sport Save To Catalog Failed': props<{ error: unknown }>(),
    'Sport Name Already In Catalog': emptyProps(),
  },
});

export const MealLogsApiActions = createActionGroup({
  source: 'Meal Logs | Meal Logs Api',
  events: {
    'Meal Logs Collection Changed': props<{ mealLogs: MealLogDocument[] }>(),
    'Insulin Dose Created': emptyProps(),
    'Insulin Dose Creation Failed': props<{ error: unknown }>(),
    'Sport Log Created': emptyProps(),
    'Sport Log Creation Failed': props<{ error: unknown }>(),
    'Meal Log Created': emptyProps(),
    'Meal Log Creation Failed': props<{ error: unknown }>(),
    'Insulin Dose Updated': emptyProps(),
    'Insulin Dose Update Failed': props<{ error: unknown }>(),
    'Meal Log Updated': emptyProps(),
    'Meal Log Update Failed': props<{ error: unknown }>(),
    'Meal Log Document Deleted': emptyProps(),
    'Meal Log Document Deletion Failed': props<{ error: unknown }>(),
    'Meal Log Reloaded Into Meal': emptyProps(),
    'Meal Log Reload Into Meal Failed': props<{ error: unknown }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Meal Logs Stream': emptyProps(),
  },
});

export const MealLogsSnackBarActions = createActionGroup({
  source: 'Meal Logs | Snack Bar',
  events: {
    'Show Reload Into Meal Snackbar Successful': emptyProps(),
    'Show Reload Into Meal Snackbar Failed': emptyProps(),
    'Go To Current Meal Clicked': emptyProps(),
    'Show Sport Saved To Catalog Snackbar': emptyProps(),
    'Show Sport Already In Catalog Snackbar': emptyProps(),
    'Show Sport Save To Catalog Failed Snackbar': emptyProps(),
  },
});
