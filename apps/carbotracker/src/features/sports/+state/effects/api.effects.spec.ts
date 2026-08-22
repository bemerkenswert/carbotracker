import { TestBed } from '@angular/core/testing';
import { Action } from '@ngrx/store';
import { provideMockActions } from '@ngrx/effects/testing';
import { MockStore, provideMockStore } from '@ngrx/store/testing';
import { of, Subject, throwError } from 'rxjs';
import { take } from 'rxjs/operators';
import { authFeature } from '../../../auth/+state/auth.store';
import { SportsService } from '../../services/sports.service';
import { SportsApiActions } from '../actions/api.actions';
import {
  CreateSportPageComponentActions,
  EditSportPageComponentActions,
} from '../actions/component.actions';
import { DeleteSportConfirmationDialogActions } from '../actions/dialog.actions';
import { sportsFeature } from '../sports.store';
import { createSport$, deleteSport$, updateSport$ } from './api.effects';

const selectedSport = {
  id: 's1',
  name: 'cycling',
  creator: 'user-a',
};

describe('updateSport$', () => {
  let actions$: Subject<Action>;
  let store: MockStore;
  let sportsService: jest.Mocked<SportsService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    sportsService = {
      updateSport: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<SportsService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [
            {
              selector: sportsFeature.selectCurrentSport,
              value: selectedSport,
            },
          ],
        }),
        { provide: SportsService, useValue: sportsService },
      ],
    });

    store = TestBed.inject(MockStore);
  });

  it('merges the existing sport with the changed sport and updates it', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      updateSport$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      EditSportPageComponentActions.saveSportClicked({
        changedSport: { name: 'running' },
      }),
    );

    expect(sportsService.updateSport).toHaveBeenCalledWith({
      ...selectedSport,
      ...{ name: 'running' },
    });
    expect(results).toEqual([SportsApiActions.updatingSportSuccessful()]);
  });

  it('dispatches updatingSportFailed when the update fails', () => {
    sportsService.updateSport.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      updateSport$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      EditSportPageComponentActions.saveSportClicked({
        changedSport: { name: 'running' },
      }),
    );

    expect(results).toEqual([
      SportsApiActions.updatingSportFailed({ error: expect.any(Error) }),
    ]);
  });

  it('does nothing when there is no selected sport', () => {
    store.overrideSelector(sportsFeature.selectCurrentSport, null);
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      updateSport$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      EditSportPageComponentActions.saveSportClicked({
        changedSport: { name: 'running' },
      }),
    );

    expect(sportsService.updateSport).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });
});

describe('deleteSport$', () => {
  let actions$: Subject<Action>;
  let sportsService: jest.Mocked<SportsService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    sportsService = {
      deleteSport: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<SportsService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        { provide: SportsService, useValue: sportsService },
      ],
    });
  });

  it('deletes the selected sport and dispatches deletingSportSuccessful', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      deleteSport$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      DeleteSportConfirmationDialogActions.confirmClicked({
        selectedSport,
      }),
    );

    expect(sportsService.deleteSport).toHaveBeenCalledWith('s1');
    expect(results).toEqual([SportsApiActions.deletingSportSuccessful()]);
  });

  it('dispatches deletingSportFailed when the delete fails', () => {
    sportsService.deleteSport.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      deleteSport$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      DeleteSportConfirmationDialogActions.confirmClicked({
        selectedSport,
      }),
    );

    expect(results).toEqual([
      SportsApiActions.deletingSportFailed({ error: expect.any(Error) }),
    ]);
  });
});

describe('createSport$', () => {
  let actions$: Subject<Action>;
  let store: MockStore;
  let sportsService: jest.Mocked<SportsService>;

  const existingSport = {
    id: 's1',
    name: 'cycling',
    creator: 'user-a',
  };

  beforeEach(() => {
    actions$ = new Subject<Action>();
    sportsService = {
      createSport: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<SportsService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [
            { selector: authFeature.selectUserId, value: 'user-a' },
            { selector: sportsFeature.selectAll, value: [] },
          ],
        }),
        { provide: SportsService, useValue: sportsService },
      ],
    });

    store = TestBed.inject(MockStore);
  });

  it('creates the sport with the user id as creator and dispatches creatingSportSuccessful', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      createSport$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      CreateSportPageComponentActions.saveSportClicked({
        newSport: { name: 'cycling' },
      }),
    );

    expect(sportsService.createSport).toHaveBeenCalledWith({
      name: 'cycling',
      creator: 'user-a',
    });
    expect(results).toEqual([SportsApiActions.creatingSportSuccessful()]);
  });

  it('does not create the sport when its name already exists ignoring case', () => {
    store.overrideSelector(sportsFeature.selectAll, [existingSport]);
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      createSport$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      CreateSportPageComponentActions.saveSportClicked({
        newSport: { name: 'Cycling' },
      }),
    );

    expect(sportsService.createSport).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });

  it('dispatches creatingSportFailed with the error payload when the create fails', () => {
    sportsService.createSport.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      createSport$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      CreateSportPageComponentActions.saveSportClicked({
        newSport: { name: 'cycling' },
      }),
    );

    expect(results).toEqual([
      SportsApiActions.creatingSportFailed({ error: expect.any(Error) }),
    ]);
  });

  it('does nothing when there is no user id', () => {
    store.overrideSelector(authFeature.selectUserId, null);
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      createSport$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      CreateSportPageComponentActions.saveSportClicked({
        newSport: { name: 'cycling' },
      }),
    );

    expect(sportsService.createSport).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });
});
