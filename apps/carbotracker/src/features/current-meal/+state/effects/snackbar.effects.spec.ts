import { TestBed } from '@angular/core/testing';
import { MatSnackBar } from '@angular/material/snack-bar';
import { provideMockActions } from '@ngrx/effects/testing';
import { Action } from '@ngrx/store';
import { provideMockStore } from '@ngrx/store/testing';
import { Observable, of, Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { CurrentMealApiActions } from '../actions/api.actions';
import { CurrentMealSnackBarActions } from '../actions/snackbar.actions';
import { MealLogsApiActions } from '../../../../meal-logs-feature/+state/meal-logs.actions';
import {
  showAddMealEntryFailedSnackbar$,
  showAddMealEntrySuccessfulSnackbar$,
  showClearCurrentMealFailedSnackbar$,
  showClearCurrentMealSuccessfulSnackbar$,
  showMealLogSavedFailedSnackbar$,
  showMealLogSavedSuccessfulSnackbar$,
  showSaveCurrentMealFailedSnackbar$,
  showSaveCurrentMealSuccessfulSnackbar$,
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

  describe('showAddMealEntrySuccessfulSnackbar$', () => {
    it('shows the add meal entry success snackbar', () => {
      const results = run(() => showAddMealEntrySuccessfulSnackbar$());

      actions$.next(CurrentMealApiActions.addMealEntrySuccessful());

      expect(snackBar.open).toHaveBeenCalledWith('The meal entry was added.');
      expect(results).toEqual([
        CurrentMealSnackBarActions.showAddMealEntrySnackbarSuccessful(),
      ]);
    });

    it('does not show the add meal entry snackbar for other actions', () => {
      const results = run(() => showAddMealEntrySuccessfulSnackbar$());

      actions$.next(CurrentMealApiActions.clearCurrentMealSuccessful());

      expect(snackBar.open).not.toHaveBeenCalled();
      expect(results).toEqual([]);
    });
  });

  describe('showAddMealEntryFailedSnackbar$', () => {
    it('shows the add meal entry failure snackbar', () => {
      const results = run(() => showAddMealEntryFailedSnackbar$());

      actions$.next(
        CurrentMealApiActions.addMealEntryFailed({ error: 'boom' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The meal entry could not be added.',
      );
      expect(results).toEqual([
        CurrentMealSnackBarActions.showAddMealEntrySnackbarFailed(),
      ]);
    });
  });

  describe('showClearCurrentMealSuccessfulSnackbar$', () => {
    it('shows the clear current meal success snackbar', () => {
      const results = run(() => showClearCurrentMealSuccessfulSnackbar$());

      actions$.next(CurrentMealApiActions.clearCurrentMealSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The current meal was cleared.',
      );
      expect(results).toEqual([
        CurrentMealSnackBarActions.showClearCurrentMealSnackbarSuccessful(),
      ]);
    });
  });

  describe('showClearCurrentMealFailedSnackbar$', () => {
    it('shows the clear current meal failure snackbar', () => {
      const results = run(() => showClearCurrentMealFailedSnackbar$());

      actions$.next(
        CurrentMealApiActions.clearCurrentMealFailed({ error: 'boom' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The current meal could not be cleared.',
      );
      expect(results).toEqual([
        CurrentMealSnackBarActions.showClearCurrentMealSnackbarFailed(),
      ]);
    });
  });

  describe('showSaveCurrentMealSuccessfulSnackbar$', () => {
    it('shows the save current meal success snackbar', () => {
      const results = run(() => showSaveCurrentMealSuccessfulSnackbar$());

      actions$.next(CurrentMealApiActions.saveCurrentMealSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith('The meal was saved.');
      expect(results).toEqual([
        CurrentMealSnackBarActions.showSaveCurrentMealSnackbarSuccessful(),
      ]);
    });
  });

  describe('showSaveCurrentMealFailedSnackbar$', () => {
    it('shows the save current meal failure snackbar', () => {
      const results = run(() => showSaveCurrentMealFailedSnackbar$());

      actions$.next(
        CurrentMealApiActions.saveCurrentMealFailed({ error: 'boom' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The meal could not be saved.',
      );
      expect(results).toEqual([
        CurrentMealSnackBarActions.showSaveCurrentMealSnackbarFailed(),
      ]);
    });
  });

  describe('showMealLogSavedSuccessfulSnackbar$', () => {
    it('shows the log meal success snackbar', () => {
      const results = run(() => showMealLogSavedSuccessfulSnackbar$());

      actions$.next(MealLogsApiActions.mealLogCreated());

      expect(snackBar.open).toHaveBeenCalledWith('The meal was logged.');
      expect(results).toEqual([
        CurrentMealSnackBarActions.showLogMealSnackbarSuccessful(),
      ]);
    });

    it('does not show the log meal snackbar for other actions', () => {
      const results = run(() => showMealLogSavedSuccessfulSnackbar$());

      actions$.next(CurrentMealApiActions.clearCurrentMealSuccessful());

      expect(snackBar.open).not.toHaveBeenCalled();
      expect(results).toEqual([]);
    });
  });

  describe('showMealLogSavedFailedSnackbar$', () => {
    it('shows the log meal failure snackbar', () => {
      const results = run(() => showMealLogSavedFailedSnackbar$());

      actions$.next(
        MealLogsApiActions.mealLogCreationFailed({ error: 'boom' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The meal could not be logged.',
      );
      expect(results).toEqual([
        CurrentMealSnackBarActions.showLogMealSnackbarFailed(),
      ]);
    });
  });
});
