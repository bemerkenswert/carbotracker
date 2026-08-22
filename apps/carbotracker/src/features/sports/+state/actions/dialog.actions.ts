import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Sport } from '../../sport.model';

export const DeleteSportConfirmationDialogActions = createActionGroup({
  source: 'Sports | Delete Sport Confirmation Dialog',
  events: {
    'Confirm Clicked': props<{ selectedSport: Sport }>(),
    'Abort Clicked': emptyProps(),
  },
});
