import { MatSnackBar } from '@angular/material/snack-bar';
import { Action } from '@ngrx/store';
import { Observable, of, Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { SettingsApiActions } from '../actions/api.actions';
import { InsulinToCarbRatiosPageSnackBarActions } from '../actions/snackbar.actions';
import {
  showInsulinToCarbRatiosUpdateFailedSnackbar$,
  showInsulinToCarbRatiosWereUpdatedSnackbar$,
} from './snackbar.effects';

jest.mock('firebase/auth', () => ({}));

const buildSnackBar = (): jest.Mocked<MatSnackBar> =>
  ({
    open: jest.fn(() => ({
      afterOpened: () => of(undefined),
    })),
  }) as unknown as jest.Mocked<MatSnackBar>;

const collectEffectOutput = (
  effect: (
    actions$: Observable<Action>,
    snackBar: MatSnackBar,
  ) => Observable<Action>,
) => {
  const snackBar = buildSnackBar();
  const actions$ = new Subject<Action>();
  const emitted: Action[] = [];
  effect(actions$.asObservable(), snackBar).pipe(take(1)).subscribe((action) =>
    emitted.push(action),
  );
  return { snackBar, actions$, emitted };
};

describe('showInsulinToCarbRatiosWereUpdatedSnackbar$', () => {
  it('shows the success snackbar and dispatches the follow-up action when the ratios were updated', () => {
    const { snackBar, actions$, emitted } = collectEffectOutput(
      showInsulinToCarbRatiosWereUpdatedSnackbar$,
    );

    actions$.next(SettingsApiActions.settingInsulinToCarbRatiosSuccessful());

    expect(snackBar.open).toHaveBeenCalledWith('Your ratios were updated.');
    expect(emitted).toEqual([
      InsulinToCarbRatiosPageSnackBarActions.showInsulinToCarbRatiosUpdatedSnackbarSuccessful(),
    ]);
  });
});

describe('showInsulinToCarbRatiosUpdateFailedSnackbar$', () => {
  it('shows the failure snackbar and dispatches the follow-up action when updating the ratios fails', () => {
    const { snackBar, actions$, emitted } = collectEffectOutput(
      showInsulinToCarbRatiosUpdateFailedSnackbar$,
    );

    actions$.next(
      SettingsApiActions.settingInsulinToCarbRatiosFailed({ error: 'nope' }),
    );

    expect(snackBar.open).toHaveBeenCalledWith(
      'Your ratios could not be updated.',
    );
    expect(emitted).toEqual([
      InsulinToCarbRatiosPageSnackBarActions.showInsulinToCarbRatiosUpdateFailedSnackbarSuccessful(),
    ]);
  });
});
