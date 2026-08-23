import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Sport } from '../../sport.model';

export const SportsPageComponentActions = createActionGroup({
  source: 'Sports | Sports Page Component',
  events: {
    'Entered Sports Page': emptyProps(),
    'Left Sports Page': emptyProps(),
    'Sport Clicked': props<{ sport: Sport }>(),
    'Add Clicked': emptyProps(),
  },
});

export const EditSportPageComponentActions = createActionGroup({
  source: 'Sports | Edit Sport Page Component',
  events: {
    'Selected Sport Changed': props<{ selectedSport: string }>(),
    'Save Sport Clicked': props<{ changedSport: Pick<Sport, 'name'> }>(),
    'Delete Clicked': props<{ selectedSport: Sport }>(),
    'Go Back Icon Clicked': emptyProps(),
  },
});

export const CreateSportPageComponentActions = createActionGroup({
  source: 'Sports | Create Sport Page Component',
  events: {
    'Save Sport Clicked': props<{ newSport: Pick<Sport, 'name'> }>(),
    'Go Back Icon Clicked': emptyProps(),
  },
});
