import { createActionGroup, emptyProps } from '@ngrx/store';

export const CreateSportPageSnackBarActions = createActionGroup({
  source: 'Sports | Create Sport Page Snack Bar',
  events: {
    'Show Create Sport Snackbar Successful': emptyProps(),
    'Show Create Sport Snackbar Failure': emptyProps(),
  },
});

export const EditSportPageSnackBarActions = createActionGroup({
  source: 'Sports | Edit Sport Page Snack Bar',
  events: {
    'Show Edit Sport Snackbar Successful': emptyProps(),
    'Show Edit Sport Snackbar Failure': emptyProps(),
  },
});

export const DeleteSportSnackBarActions = createActionGroup({
  source: 'Sports | Delete Sport Snack Bar',
  events: {
    'Show Delete Sport Snackbar Successful': emptyProps(),
    'Show Delete Sport Snackbar Failure': emptyProps(),
  },
});
