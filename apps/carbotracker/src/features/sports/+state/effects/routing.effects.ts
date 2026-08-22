import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { exhaustMap, from } from 'rxjs';
import { SportsApiActions } from '../actions/api.actions';
import {
  CreateSportPageComponentActions,
  EditSportPageComponentActions,
  SportsPageComponentActions,
} from '../actions/component.actions';

export const navigateToEditSport$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SportsPageComponentActions.sportClicked),
      exhaustMap(({ sport }) =>
        from(router.navigate(['app', 'sports', sport.id])),
      ),
    ),
  { dispatch: false, functional: true },
);

export const navigateToCreateSport$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(SportsPageComponentActions.addClicked),
      exhaustMap(() => from(router.navigate(['app', 'sports', 'create']))),
    ),
  { dispatch: false, functional: true },
);

export const navigateToSportsPage$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(
        SportsApiActions.deletingSportSuccessful,
        SportsApiActions.creatingSportSuccessful,
        SportsApiActions.updatingSportSuccessful,
        CreateSportPageComponentActions.goBackIconClicked,
        EditSportPageComponentActions.goBackIconClicked,
      ),
      exhaustMap(() => from(router.navigate(['app', 'sports']))),
    ),
  { dispatch: false, functional: true },
);
