import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Sport } from '../../sport.model';

export const SportsApiActions = createActionGroup({
  source: 'Sports | Sports Api',
  events: {
    'Sports Collection Changed': props<{ sports: Sport[] }>(),
    'Unsubscribed From Sports Stream': emptyProps(),
    'Updating Sport Successful': emptyProps(),
    'Updating Sport Failed': props<{ error: unknown }>(),
    'Creating Sport Successful': emptyProps(),
    'Creating Sport Failed': props<{ error: unknown }>(),
    'Deleting Sport Successful': emptyProps(),
    'Deleting Sport Failed': props<{ error: unknown }>(),
  },
});
