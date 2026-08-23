import { TestBed } from '@angular/core/testing';
import { ConfirmationDialogService } from '@carbotracker/ui';
import { Action } from '@ngrx/store';
import { provideMockActions } from '@ngrx/effects/testing';
import { provideMockStore } from '@ngrx/store/testing';
import { Observable, of, Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { Sport } from '../../sport.model';
import { EditSportPageComponentActions } from '../actions/component.actions';
import { DeleteSportConfirmationDialogActions } from '../actions/dialog.actions';
import { showDeleteConfirmationDialog$ } from './dialog.effects';

describe('showDeleteConfirmationDialog$', () => {
  let actions$: Subject<Action>;
  let confirmationDialogService: jest.Mocked<ConfirmationDialogService>;

  const run = (): Action[] => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      showDeleteConfirmationDialog$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    return results;
  };

  beforeEach(() => {
    actions$ = new Subject<Action>();
    confirmationDialogService = {
      openDeleteConfirmationDialog: jest.fn(),
    } as unknown as jest.Mocked<ConfirmationDialogService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore(),
        {
          provide: ConfirmationDialogService,
          useValue: confirmationDialogService,
        },
      ],
    });
  });

  it('opens the delete confirmation dialog and dispatches confirmClicked when confirmed', () => {
    const sport: Sport = {
      id: 's1',
      name: 'cycling',
      creator: 'user-a',
    };
    confirmationDialogService.openDeleteConfirmationDialog.mockReturnValue(
      of({ confirmed: true }),
    );
    const results = run();

    actions$.next(
      EditSportPageComponentActions.deleteClicked({ selectedSport: sport }),
    );

    expect(
      confirmationDialogService.openDeleteConfirmationDialog,
    ).toHaveBeenCalledWith('cycling');
    expect(results).toEqual([
      DeleteSportConfirmationDialogActions.confirmClicked({
        selectedSport: sport,
      }),
    ]);
  });

  it('dispatches abortClicked when the user aborts the dialog', () => {
    const sport: Sport = {
      id: 's1',
      name: 'cycling',
      creator: 'user-a',
    };
    confirmationDialogService.openDeleteConfirmationDialog.mockReturnValue(
      of({ confirmed: false }),
    );
    const results = run();

    actions$.next(
      EditSportPageComponentActions.deleteClicked({ selectedSport: sport }),
    );

    expect(results).toEqual([
      DeleteSportConfirmationDialogActions.abortClicked(),
    ]);
  });

  it('does not open the dialog for other actions', () => {
    const results = run();

    actions$.next(
      EditSportPageComponentActions.selectedSportChanged({
        selectedSport: 's1',
      }),
    );

    expect(
      confirmationDialogService.openDeleteConfirmationDialog,
    ).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });
});
