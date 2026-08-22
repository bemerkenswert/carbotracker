import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { Action } from '@ngrx/store';
import { provideMockActions } from '@ngrx/effects/testing';
import { provideMockStore } from '@ngrx/store/testing';
import { Observable, of, Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { Sport } from '../../sport.model';
import { SportsApiActions } from '../actions/api.actions';
import { SportsPageComponentActions } from '../actions/component.actions';
import {
  navigateToCreateSport$,
  navigateToEditSport$,
  navigateToSportsPage$,
} from './routing.effects';

const sport: Sport = {
  id: 's1',
  name: 'cycling',
  creator: 'user-a',
};

describe('routing effects', () => {
  let actions$: Subject<Action>;
  let router: Router;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    router = {
      navigate: jest.fn(() => of(true)),
    } as unknown as Router;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore(),
        { provide: Router, useValue: router },
      ],
    });
  });

  const run = (effect: () => Observable<unknown>): void => {
    TestBed.runInInjectionContext(() => effect().pipe(take(1)).subscribe());
  };

  it('navigates to the edit sport page when a sport is clicked', () => {
    run(() => navigateToEditSport$());

    actions$.next(SportsPageComponentActions.sportClicked({ sport }));

    expect(router.navigate).toHaveBeenCalledWith(['app', 'sports', 's1']);
  });

  it('navigates to the create sport page when add is clicked', () => {
    run(() => navigateToCreateSport$());

    actions$.next(SportsPageComponentActions.addClicked());

    expect(router.navigate).toHaveBeenCalledWith(['app', 'sports', 'create']);
  });

  it('navigates to the sports page after the sport is deleted', () => {
    run(() => navigateToSportsPage$());

    actions$.next(SportsApiActions.deletingSportSuccessful());

    expect(router.navigate).toHaveBeenCalledWith(['app', 'sports']);
  });

  it('does not navigate to the sports page when deleting the sport fails', () => {
    run(() => navigateToSportsPage$());

    actions$.next(SportsApiActions.deletingSportFailed({ error: 'boom' }));

    expect(router.navigate).not.toHaveBeenCalled();
  });

  it('does not navigate for other actions', () => {
    run(() => navigateToEditSport$());

    actions$.next(SportsPageComponentActions.enteredSportsPage());

    expect(router.navigate).not.toHaveBeenCalled();
  });
});
