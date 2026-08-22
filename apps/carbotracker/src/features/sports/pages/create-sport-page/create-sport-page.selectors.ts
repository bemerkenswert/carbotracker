import { createSelector } from '@ngrx/store';
import { sportsFeature } from '../../+state';

export interface CreateSportPageViewModel {
  pageTitle: string;
  initialFormValues: { name: string };
}

export const selectCreateSportPageViewModel = createSelector(
  (): CreateSportPageViewModel => ({
    pageTitle: 'Create sport',
    initialFormValues: { name: '' },
  }),
);

export const selectSportNameAlreadyExists = createSelector(
  sportsFeature.selectAll,
  (sports) =>
    (name: string): boolean =>
      sports.some(
        (sport) =>
          sport.name.trim().toLowerCase() === name.trim().toLowerCase(),
      ),
);
