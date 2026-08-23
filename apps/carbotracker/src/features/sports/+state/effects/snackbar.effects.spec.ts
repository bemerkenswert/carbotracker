import { TestBed } from '@angular/core/testing';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Action } from '@ngrx/store';
import { provideMockActions } from '@ngrx/effects/testing';
import { provideMockStore } from '@ngrx/store/testing';
import { Observable, of, Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { SportsApiActions } from '../actions/api.actions';
import {
  CreateSportPageSnackBarActions,
  DeleteSportSnackBarActions,
  EditSportPageSnackBarActions,
} from '../actions/snackbar.actions';
import {
  showCreateSportFailedSnackbar$,
  showDeleteSportFailedSnackbar$,
  showSportWasChangedSnackbar$,
  showSportWasCreatedSnackbar$,
  showSportWasDeletedSnackbar$,
  showUpdateSportFailedSnackbar$,
} from './snackbar.effects';

describe('snackbar effects', () => {
  let actions$: Subject<Action>;
  let snackBar: jest.Mocked<MatSnackBar>;

  const run = (effect: () => Observable<Action>): Action[] => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      effect()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    return results;
  };

  beforeEach(() => {
    actions$ = new Subject<Action>();
    const afterOpened = jest.fn(() => of(void 0));
    snackBar = {
      open: jest.fn(() => ({ afterOpened })),
    } as unknown as jest.Mocked<MatSnackBar>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore(),
        { provide: MatSnackBar, useValue: snackBar },
      ],
    });
  });

  describe('showSportWasCreatedSnackbar$', () => {
    it('shows a success snackbar when sport is created', () => {
      const results = run(() => showSportWasCreatedSnackbar$());

      actions$.next(SportsApiActions.creatingSportSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The sport was added successfully.',
      );
      expect(results).toEqual([
        CreateSportPageSnackBarActions.showCreateSportSnackbarSuccessful(),
      ]);
    });
  });

  describe('showCreateSportFailedSnackbar$', () => {
    it('shows a failure snackbar when sport creation fails', () => {
      const results = run(() => showCreateSportFailedSnackbar$());

      actions$.next(SportsApiActions.creatingSportFailed({ error: 'error' }));

      expect(snackBar.open).toHaveBeenCalledWith(
        'The sport could not be added.',
      );
      expect(results).toEqual([
        CreateSportPageSnackBarActions.showCreateSportSnackbarFailure(),
      ]);
    });
  });

  describe('showSportWasChangedSnackbar$', () => {
    it('shows a success snackbar when sport is updated', () => {
      const results = run(() => showSportWasChangedSnackbar$());

      actions$.next(SportsApiActions.updatingSportSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The sport was updated successfully.',
      );
      expect(results).toEqual([
        EditSportPageSnackBarActions.showEditSportSnackbarSuccessful(),
      ]);
    });
  });

  describe('showUpdateSportFailedSnackbar$', () => {
    it('shows a failure snackbar when sport update fails', () => {
      const results = run(() => showUpdateSportFailedSnackbar$());

      actions$.next(SportsApiActions.updatingSportFailed({ error: 'error' }));

      expect(snackBar.open).toHaveBeenCalledWith(
        'The sport could not be updated.',
      );
      expect(results).toEqual([
        EditSportPageSnackBarActions.showEditSportSnackbarFailure(),
      ]);
    });
  });

  describe('showSportWasDeletedSnackbar$', () => {
    it('shows a success snackbar when sport is deleted', () => {
      const results = run(() => showSportWasDeletedSnackbar$());

      actions$.next(SportsApiActions.deletingSportSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The sport was deleted successfully.',
      );
      expect(results).toEqual([
        DeleteSportSnackBarActions.showDeleteSportSnackbarSuccessful(),
      ]);
    });
  });

  describe('showDeleteSportFailedSnackbar$', () => {
    it('shows a failure snackbar when sport deletion fails', () => {
      const results = run(() => showDeleteSportFailedSnackbar$());

      actions$.next(SportsApiActions.deletingSportFailed({ error: 'error' }));

      expect(snackBar.open).toHaveBeenCalledWith(
        'The sport could not be deleted.',
      );
      expect(results).toEqual([
        DeleteSportSnackBarActions.showDeleteSportSnackbarFailure(),
      ]);
    });
  });
});
