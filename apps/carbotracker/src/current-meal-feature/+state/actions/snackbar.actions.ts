import { createActionGroup, emptyProps } from '@ngrx/store';

export const CurrentMealSnackBarActions = createActionGroup({
  source: 'Current Meal | Snack Bar',
  events: {
    'Show Add Meal Entry Snackbar Successful': emptyProps(),
    'Show Add Meal Entry Snackbar Failed': emptyProps(),
    'Show Clear Current Meal Snackbar Successful': emptyProps(),
    'Show Clear Current Meal Snackbar Failed': emptyProps(),
    'Show Save Current Meal Snackbar Successful': emptyProps(),
    'Show Save Current Meal Snackbar Failed': emptyProps(),
  },
});
