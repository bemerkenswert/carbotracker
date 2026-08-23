import { createSelector } from '@ngrx/store';
import { sportsFeature } from '../../+state';
import { Sport } from '../../sport.model';

export interface EditSportPageViewModel {
  sport: Sport | null;
  pageTitle: string;
  initialFormValues: Pick<Sport, 'name'> | null;
}

export const selectEditSportPageViewModel = createSelector(
  sportsFeature.selectCurrentSport,
  (sport): EditSportPageViewModel => ({
    sport,
    pageTitle: 'Edit sport',
    initialFormValues: sport ? { name: sport.name } : null,
  }),
);
