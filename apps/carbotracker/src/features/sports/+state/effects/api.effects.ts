import { inject } from '@angular/core';
import { filterNull } from '@carbotracker/utility';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { concatLatestFrom, mapResponse } from '@ngrx/operators';
import { Store } from '@ngrx/store';
import { exhaustMap, filter, map, mergeMap, switchMap, tap } from 'rxjs';
import {
  AuthApiActions,
  LogoutApiActions,
} from '../../../auth/+state/actions/api.actions';
import { authFeature } from '../../../auth/+state/auth.store';
import { SportsService } from '../../services/sports.service';
import { SportsApiActions } from '../actions/api.actions';
import {
  CreateSportPageComponentActions,
  EditSportPageComponentActions,
} from '../actions/component.actions';
import { DeleteSportConfirmationDialogActions } from '../actions/dialog.actions';
import { sportsFeature } from '../sports.store';

export const startStreamingSports$ = createEffect(
  (
    actions$ = inject(Actions),
    sportsService = inject(SportsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(AuthApiActions.userIsLoggedIn),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          sportsService.subscribeToOwnSports({ uid });
        }
      }),
    ),
  { dispatch: false, functional: true },
);

export const stopStreamingSports$ = createEffect(
  (actions$ = inject(Actions), sportsService = inject(SportsService)) =>
    actions$.pipe(
      ofType(LogoutApiActions.logoutSuccessful),
      tap(() => {
        sportsService.unsubscribeFromOwnSports();
      }),
    ),
  { dispatch: false, functional: true },
);

export const updateSport$ = createEffect(
  (
    actions$ = inject(Actions),
    sportsService = inject(SportsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(EditSportPageComponentActions.saveSportClicked),
      concatLatestFrom(() =>
        store.select(sportsFeature.selectCurrentSport).pipe(filterNull()),
      ),
      exhaustMap(([{ changedSport }, existingSport]) =>
        sportsService
          .updateSport({
            ...existingSport,
            ...changedSport,
          })
          .pipe(
            mapResponse({
              next: () => SportsApiActions.updatingSportSuccessful(),
              error: (error) => SportsApiActions.updatingSportFailed({ error }),
            }),
          ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const deleteSport$ = createEffect(
  (actions$ = inject(Actions), sportsService = inject(SportsService)) =>
    actions$.pipe(
      ofType(DeleteSportConfirmationDialogActions.confirmClicked),
      exhaustMap(({ selectedSport }) =>
        sportsService.deleteSport(selectedSport.id).pipe(
          mapResponse({
            next: () => SportsApiActions.deletingSportSuccessful(),
            error: (error) => SportsApiActions.deletingSportFailed({ error }),
          }),
        ),
      ),
    ),
  { dispatch: true, functional: true },
);

export const createSport$ = createEffect(
  (
    actions$ = inject(Actions),
    sportsService = inject(SportsService),
    store = inject(Store),
  ) =>
    actions$.pipe(
      ofType(CreateSportPageComponentActions.saveSportClicked),
      concatLatestFrom(() => [
        store.select(authFeature.selectUserId).pipe(filterNull()),
        store.select(sportsFeature.selectAll),
      ]),
      filter(
        ([{ newSport }, , sports]) =>
          !sports.some(
            (sport) =>
              sport.name.trim().toLowerCase() ===
              newSport.name.trim().toLowerCase(),
          ),
      ),
      map(([{ newSport }, userId]) => ({ ...newSport, creator: userId })),
      mergeMap((newSport) =>
        sportsService.createSport({ ...newSport }).pipe(
          mapResponse({
            next: () => SportsApiActions.creatingSportSuccessful(),
            error: (error) => SportsApiActions.creatingSportFailed({ error }),
          }),
        ),
      ),
    ),
  { dispatch: true, functional: true },
);
