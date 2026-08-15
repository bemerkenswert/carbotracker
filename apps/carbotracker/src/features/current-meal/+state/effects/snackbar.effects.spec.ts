import { MatSnackBar } from '@angular/material/snack-bar';
import { Action } from '@ngrx/store';
import { Observable, of, Subject } from 'rxjs';
import { CurrentMealApiActions } from '../actions/api.actions';
import { CurrentMealSnackBarActions } from '../actions/snackbar.actions';
import {
  showAddMealEntryFailedSnackbar$,
  showAddMealEntrySuccessfulSnackbar$,
  showClearCurrentMealFailedSnackbar$,
  showClearCurrentMealSuccessfulSnackbar$,
  showSaveCurrentMealFailedSnackbar$,
  showSaveCurrentMealSuccessfulSnackbar$,
} from './snackbar.effects';

const buildSnackBar = (): MatSnackBar =>
  ({
    open: jest.fn().mockReturnValue({
      afterOpened: jest.fn().mockReturnValue(of(undefined)),
    }),
  }) as unknown as MatSnackBar;

const buildEffect = (
  effect: (
    actions$: Observable<Action>,
    snackBar: MatSnackBar,
  ) => Observable<Action>,
) => {
  const actions$ = new Subject<Action>();
  const snackBar = buildSnackBar();
  const results: Action[] = [];
  effect(actions$.asObservable(), snackBar).subscribe((action) =>
    results.push(action),
  );
  return { actions$, snackBar, results };
};

describe('snackbar effects', () => {
  it('shows the add meal entry success snackbar', () => {
    const { actions$, snackBar, results } = buildEffect(
      showAddMealEntrySuccessfulSnackbar$,
    );

    actions$.next(CurrentMealApiActions.addMealEntrySuccessful());

    expect(snackBar.open).toHaveBeenCalledWith('The meal entry was added.');
    expect(results).toEqual([
      CurrentMealSnackBarActions.showAddMealEntrySnackbarSuccessful(),
    ]);
  });

  it('shows the add meal entry failure snackbar', () => {
    const { actions$, snackBar, results } = buildEffect(
      showAddMealEntryFailedSnackbar$,
    );

    actions$.next(CurrentMealApiActions.addMealEntryFailed({ error: 'boom' }));

    expect(snackBar.open).toHaveBeenCalledWith(
      'The meal entry could not be added.',
    );
    expect(results).toEqual([
      CurrentMealSnackBarActions.showAddMealEntrySnackbarFailed(),
    ]);
  });

  it('shows the clear current meal success snackbar', () => {
    const { actions$, snackBar, results } = buildEffect(
      showClearCurrentMealSuccessfulSnackbar$,
    );

    actions$.next(CurrentMealApiActions.clearCurrentMealSuccessful());

    expect(snackBar.open).toHaveBeenCalledWith('The current meal was cleared.');
    expect(results).toEqual([
      CurrentMealSnackBarActions.showClearCurrentMealSnackbarSuccessful(),
    ]);
  });

  it('shows the clear current meal failure snackbar', () => {
    const { actions$, snackBar, results } = buildEffect(
      showClearCurrentMealFailedSnackbar$,
    );

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

  it('does not show the add meal entry snackbar for other actions', () => {
    const { actions$, snackBar } = buildEffect(
      showAddMealEntrySuccessfulSnackbar$,
    );

    actions$.next(CurrentMealApiActions.clearCurrentMealSuccessful());

    expect(snackBar.open).not.toHaveBeenCalled();
  });

  it('shows the save current meal success snackbar', () => {
    const { actions$, snackBar, results } = buildEffect(
      showSaveCurrentMealSuccessfulSnackbar$,
    );

    actions$.next(CurrentMealApiActions.saveCurrentMealSuccessful());

    expect(snackBar.open).toHaveBeenCalledWith('The meal was saved.');
    expect(results).toEqual([
      CurrentMealSnackBarActions.showSaveCurrentMealSnackbarSuccessful(),
    ]);
  });

  it('shows the save current meal failure snackbar', () => {
    const { actions$, snackBar, results } = buildEffect(
      showSaveCurrentMealFailedSnackbar$,
    );

    actions$.next(
      CurrentMealApiActions.saveCurrentMealFailed({ error: 'boom' }),
    );

    expect(snackBar.open).toHaveBeenCalledWith('The meal could not be saved.');
    expect(results).toEqual([
      CurrentMealSnackBarActions.showSaveCurrentMealSnackbarFailed(),
    ]);
  });
});
