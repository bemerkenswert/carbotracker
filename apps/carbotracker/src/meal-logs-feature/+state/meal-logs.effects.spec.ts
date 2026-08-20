import { ConfirmationDialogService } from '@carbotracker/ui';
import { Router } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Store } from '@ngrx/store';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Action } from '@ngrx/store';
import { of, Subject, throwError } from 'rxjs';
import { take } from 'rxjs/operators';
import { authFeature } from '../../features/auth/+state/auth.store';
import { EditMealLogDialogService } from '../edit-meal-log-dialog/edit-meal-log-dialog.service';
import { InsulinDoseDialogService } from '../insulin-dose-dialog/insulin-dose-dialog.service';
import { MealLog, MealLogDocument } from '../meal-log.model';
import { MealLogsService } from '../services/meal-logs.service';
import {
  HistoryPageComponentActions,
  MealLogsApiActions,
  MealLogsSnackBarActions,
} from './meal-logs.actions';
import {
  createInsulinDose$,
  deleteMealLogDocument$,
  editInsulinDose$,
  editMealLog$,
  navigateToCurrentMeal$,
  reloadMealLogIntoMeal$,
  showReloadIntoMealFailedSnackbar$,
  showReloadIntoMealSuccessfulSnackbar$,
  startStreamingMealLogs$,
  stopStreamingMealLogs$,
} from './meal-logs.effects';

const navigateTo = (url: string) =>
  routerNavigatedAction({
    payload: {
      routerState: {},
      event: { urlAfterRedirects: url },
    } as never,
  });

describe('startStreamingMealLogs$', () => {
  it('subscribes to the user meal logs when navigating to history', () => {
    const mealLogsService = {
      subscribeToOwnMealLogs: jest.fn(),
      unsubscribeFromOwnMealLogs: jest.fn(),
    } as unknown as MealLogsService;
    const store = {
      select: jest.fn(() => of('user-1')),
    } as unknown as Store;

    const actions$ = new Subject<Action>();
    const effect$ = startStreamingMealLogs$(
      actions$.asObservable(),
      mealLogsService,
      store,
    );
    effect$.pipe(take(1)).subscribe();

    actions$.next(navigateTo('/app/history'));

    expect(mealLogsService.subscribeToOwnMealLogs).toHaveBeenCalledWith({
      uid: 'user-1',
    });
  });

  it('does not subscribe when navigating away from history', () => {
    const mealLogsService = {
      subscribeToOwnMealLogs: jest.fn(),
      unsubscribeFromOwnMealLogs: jest.fn(),
    } as unknown as MealLogsService;
    const store = {
      select: jest.fn(() => of('user-1')),
    } as unknown as Store;

    const actions$ = new Subject<Action>();
    const effect$ = startStreamingMealLogs$(
      actions$.asObservable(),
      mealLogsService,
      store,
    );
    effect$.pipe(take(1)).subscribe();

    actions$.next(navigateTo('/app/settings'));

    expect(mealLogsService.subscribeToOwnMealLogs).not.toHaveBeenCalled();
  });
});

describe('stopStreamingMealLogs$', () => {
  it('unsubscribes when leaving the history page', () => {
    const mealLogsService = {
      subscribeToOwnMealLogs: jest.fn(),
      unsubscribeFromOwnMealLogs: jest.fn(),
    } as unknown as MealLogsService;

    const actions$ = new Subject<Action>();
    const effect$ = stopStreamingMealLogs$(
      actions$.asObservable(),
      mealLogsService,
    );
    effect$.pipe(take(1)).subscribe();

    actions$.next(HistoryPageComponentActions.leftHistoryPage());

    expect(mealLogsService.unsubscribeFromOwnMealLogs).toHaveBeenCalled();
  });
});

describe('createInsulinDose$', () => {
  const buildStore = (): Store =>
    ({
      select: jest.fn((selector) => {
        if (selector === authFeature.selectUserId) {
          return of('user-1');
        }
        return of(null);
      }),
    }) as unknown as Store;

  const buildMocks = () => {
    const mealLogsService = {
      createInsulinDose: jest.fn(() => of(undefined)),
    } as unknown as MealLogsService;
    const insulinDoseDialogService = {
      open: jest.fn(),
    } as unknown as jest.Mocked<InsulinDoseDialogService>;
    return { mealLogsService, insulinDoseDialogService };
  };

  it('creates an insulin dose when the user confirms the dialog', () => {
    const { mealLogsService, insulinDoseDialogService } = buildMocks();
    insulinDoseDialogService.open.mockReturnValue(
      of({
        cancelled: false,
        date: new Date('2026-08-10T08:00'),
        insulin: 3,
        note: 'after breakfast',
      }),
    );

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    createInsulinDose$(
      actions$.asObservable(),
      insulinDoseDialogService,
      mealLogsService,
      buildStore(),
    )
      .pipe(take(1))
      .subscribe((action) => results.push(action));

    actions$.next(HistoryPageComponentActions.logInsulinDoseClicked());

    expect(insulinDoseDialogService.open).toHaveBeenCalled();
    expect(mealLogsService.createInsulinDose).toHaveBeenCalledWith({
      date: new Date('2026-08-10T08:00'),
      insulin: 3,
      note: 'after breakfast',
      uid: 'user-1',
    });
    expect(results).toEqual([MealLogsApiActions.insulinDoseCreated()]);
  });

  it('does not create an insulin dose when the user cancels the dialog', () => {
    const { mealLogsService, insulinDoseDialogService } = buildMocks();
    insulinDoseDialogService.open.mockReturnValue(of({ cancelled: true }));

    const actions$ = new Subject<Action>();
    createInsulinDose$(
      actions$.asObservable(),
      insulinDoseDialogService,
      mealLogsService,
      buildStore(),
    )
      .pipe(take(1))
      .subscribe();

    actions$.next(HistoryPageComponentActions.logInsulinDoseClicked());

    expect(insulinDoseDialogService.open).toHaveBeenCalled();
    expect(mealLogsService.createInsulinDose).not.toHaveBeenCalled();
  });

  it('dispatches insulinDoseCreationFailed when saving fails', () => {
    const { mealLogsService, insulinDoseDialogService } = buildMocks();
    insulinDoseDialogService.open.mockReturnValue(
      of({
        cancelled: false,
        date: new Date('2026-08-10T08:00'),
        insulin: 3,
        note: null,
      }),
    );
    mealLogsService.createInsulinDose.mockReturnValue(
      throwError(() => new Error('boom')),
    );

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    createInsulinDose$(
      actions$.asObservable(),
      insulinDoseDialogService,
      mealLogsService,
      buildStore(),
    )
      .pipe(take(1))
      .subscribe((action) => results.push(action));

    actions$.next(HistoryPageComponentActions.logInsulinDoseClicked());

    expect(results).toEqual([
      MealLogsApiActions.insulinDoseCreationFailed({
        error: expect.any(Error),
      }),
    ]);
  });
});

const createDose = (
  id = 'd1',
  createdAt = new Date('2026-08-10T08:00'),
): MealLogDocument => ({
  id,
  type: 'insulin-dose',
  createdAt,
  date: '2026-08-10',
  insulin: 3,
  note: 'after breakfast',
  creator: 'user-1',
});

const createMealLog = (
  id = 'm1',
  createdAt = new Date('2026-08-10T12:00'),
): MealLog => ({
  id,
  type: 'meal-log',
  createdAt,
  date: '2026-08-10',
  mealType: 'lunch',
  mealEntries: [{ productId: 'p1', name: 'Pasta', carbs: 50, amount: 100 }],
  insulinToCarbRatio: 1,
  estimatedInsulin: 2,
  actualInsulin: 2.5,
  note: 'good meal',
  creator: 'user-1',
});

describe('editInsulinDose$', () => {
  it('opens the edit dialog pre-filled and updates the dose on confirm', () => {
    const mealLogsService = {
      updateInsulinDose: jest.fn(() => of(undefined)),
    } as unknown as MealLogsService;
    const insulinDoseDialogService = {
      open: jest.fn(() =>
        of({
          cancelled: false,
          date: new Date('2026-08-10T09:00'),
          insulin: 4,
          note: 'updated note',
        }),
      ),
    } as unknown as jest.Mocked<InsulinDoseDialogService>;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    editInsulinDose$(
      actions$.asObservable(),
      insulinDoseDialogService,
      mealLogsService,
    ).subscribe((action) => results.push(action));

    actions$.next(
      HistoryPageComponentActions.editInsulinDoseClicked({
        mealLog: createDose(),
      }),
    );

    expect(insulinDoseDialogService.open).toHaveBeenCalledWith({
      dose: {
        createdAt: new Date('2026-08-10T08:00'),
        insulin: 3,
        note: 'after breakfast',
      },
    });
    expect(mealLogsService.updateInsulinDose).toHaveBeenCalledWith({
      id: 'd1',
      date: new Date('2026-08-10T09:00'),
      insulin: 4,
      note: 'updated note',
    });
    expect(results).toEqual([MealLogsApiActions.insulinDoseUpdated()]);
  });

  it('does not update when the dialog is cancelled', () => {
    const mealLogsService = {
      updateInsulinDose: jest.fn(() => of(undefined)),
    } as unknown as MealLogsService;
    const insulinDoseDialogService = {
      open: jest.fn(() => of({ cancelled: true })),
    } as unknown as jest.Mocked<InsulinDoseDialogService>;

    const actions$ = new Subject<Action>();
    editInsulinDose$(
      actions$.asObservable(),
      insulinDoseDialogService,
      mealLogsService,
    ).subscribe();

    actions$.next(
      HistoryPageComponentActions.editInsulinDoseClicked({
        mealLog: createDose(),
      }),
    );

    expect(mealLogsService.updateInsulinDose).not.toHaveBeenCalled();
  });

  it('dispatches insulinDoseUpdateFailed when saving fails', () => {
    const mealLogsService = {
      updateInsulinDose: jest.fn(() => throwError(() => new Error('boom'))),
    } as unknown as MealLogsService;
    const insulinDoseDialogService = {
      open: jest.fn(() =>
        of({
          cancelled: false,
          date: new Date('2026-08-10T09:00'),
          insulin: 4,
          note: null,
        }),
      ),
    } as unknown as jest.Mocked<InsulinDoseDialogService>;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    editInsulinDose$(
      actions$.asObservable(),
      insulinDoseDialogService,
      mealLogsService,
    ).subscribe((action) => results.push(action));

    actions$.next(
      HistoryPageComponentActions.editInsulinDoseClicked({
        mealLog: createDose(),
      }),
    );

    expect(results).toEqual([
      MealLogsApiActions.insulinDoseUpdateFailed({ error: expect.any(Error) }),
    ]);
  });
});

describe('editMealLog$', () => {
  it('opens the edit dialog pre-filled and updates the meal log on confirm', () => {
    const mealLogsService = {
      updateMealLog: jest.fn(() => of(undefined)),
    } as unknown as MealLogsService;
    const editMealLogDialogService = {
      open: jest.fn(() =>
        of({
          cancelled: false,
          date: new Date('2026-08-10T13:00'),
          mealType: 'dinner',
          actualInsulin: 3,
          note: 'new note',
        }),
      ),
    } as unknown as jest.Mocked<EditMealLogDialogService>;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    editMealLog$(
      actions$.asObservable(),
      editMealLogDialogService,
      mealLogsService,
    ).subscribe((action) => results.push(action));

    actions$.next(
      HistoryPageComponentActions.editMealLogClicked({
        mealLog: createMealLog(),
      }),
    );

    expect(editMealLogDialogService.open).toHaveBeenCalledWith({
      mealLog: {
        createdAt: new Date('2026-08-10T12:00'),
        mealType: 'lunch',
        estimatedInsulin: 2,
        actualInsulin: 2.5,
        note: 'good meal',
      },
    });
    expect(mealLogsService.updateMealLog).toHaveBeenCalledWith({
      id: 'm1',
      date: new Date('2026-08-10T13:00'),
      mealType: 'dinner',
      actualInsulin: 3,
      note: 'new note',
    });
    expect(results).toEqual([MealLogsApiActions.mealLogUpdated()]);
  });

  it('does not update when the dialog is cancelled', () => {
    const mealLogsService = {
      updateMealLog: jest.fn(() => of(undefined)),
    } as unknown as MealLogsService;
    const editMealLogDialogService = {
      open: jest.fn(() => of({ cancelled: true })),
    } as unknown as jest.Mocked<EditMealLogDialogService>;

    const actions$ = new Subject<Action>();
    editMealLog$(
      actions$.asObservable(),
      editMealLogDialogService,
      mealLogsService,
    ).subscribe();

    actions$.next(
      HistoryPageComponentActions.editMealLogClicked({
        mealLog: createMealLog(),
      }),
    );

    expect(mealLogsService.updateMealLog).not.toHaveBeenCalled();
  });

  it('dispatches mealLogUpdateFailed when saving fails', () => {
    const mealLogsService = {
      updateMealLog: jest.fn(() => throwError(() => new Error('boom'))),
    } as unknown as MealLogsService;
    const editMealLogDialogService = {
      open: jest.fn(() =>
        of({
          cancelled: false,
          date: new Date('2026-08-10T13:00'),
          mealType: 'dinner',
          actualInsulin: 3,
          note: null,
        }),
      ),
    } as unknown as jest.Mocked<EditMealLogDialogService>;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    editMealLog$(
      actions$.asObservable(),
      editMealLogDialogService,
      mealLogsService,
    ).subscribe((action) => results.push(action));

    actions$.next(
      HistoryPageComponentActions.editMealLogClicked({
        mealLog: createMealLog(),
      }),
    );

    expect(results).toEqual([
      MealLogsApiActions.mealLogUpdateFailed({ error: expect.any(Error) }),
    ]);
  });
});

describe('deleteMealLogDocument$', () => {
  const buildMocks = () => {
    const mealLogsService = {
      deleteMealLogDocument: jest.fn(() => of(undefined)),
    } as unknown as MealLogsService;
    const confirmationDialogService = {
      openDeleteConfirmationDialog: jest.fn(),
    } as unknown as jest.Mocked<ConfirmationDialogService>;
    return { mealLogsService, confirmationDialogService };
  };

  it('deletes the entry when the user confirms', () => {
    const { mealLogsService, confirmationDialogService } = buildMocks();
    confirmationDialogService.openDeleteConfirmationDialog.mockReturnValue(
      of({ confirmed: true }),
    );

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    deleteMealLogDocument$(
      actions$.asObservable(),
      confirmationDialogService,
      mealLogsService,
    ).subscribe((action) => results.push(action));

    actions$.next(
      HistoryPageComponentActions.deleteMealLogDocumentClicked({
        mealLog: createDose(),
      }),
    );

    expect(
      confirmationDialogService.openDeleteConfirmationDialog,
    ).toHaveBeenCalled();
    expect(mealLogsService.deleteMealLogDocument).toHaveBeenCalledWith({
      id: 'd1',
    });
    expect(results).toEqual([MealLogsApiActions.mealLogDocumentDeleted()]);
  });

  it('leaves the entry unchanged when the user cancels', () => {
    const { mealLogsService, confirmationDialogService } = buildMocks();
    confirmationDialogService.openDeleteConfirmationDialog.mockReturnValue(
      of({ confirmed: false }),
    );

    const actions$ = new Subject<Action>();
    deleteMealLogDocument$(
      actions$.asObservable(),
      confirmationDialogService,
      mealLogsService,
    ).subscribe();

    actions$.next(
      HistoryPageComponentActions.deleteMealLogDocumentClicked({
        mealLog: createDose(),
      }),
    );

    expect(mealLogsService.deleteMealLogDocument).not.toHaveBeenCalled();
  });

  it('dispatches mealLogDocumentDeletionFailed when deletion fails', () => {
    const { mealLogsService, confirmationDialogService } = buildMocks();
    confirmationDialogService.openDeleteConfirmationDialog.mockReturnValue(
      of({ confirmed: true }),
    );
    mealLogsService.deleteMealLogDocument.mockReturnValue(
      throwError(() => new Error('boom')),
    );

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    deleteMealLogDocument$(
      actions$.asObservable(),
      confirmationDialogService,
      mealLogsService,
    ).subscribe((action) => results.push(action));

    actions$.next(
      HistoryPageComponentActions.deleteMealLogDocumentClicked({
        mealLog: createDose(),
      }),
    );

    expect(results).toEqual([
      MealLogsApiActions.mealLogDocumentDeletionFailed({
        error: expect.any(Error),
      }),
    ]);
  });
});

describe('reloadMealLogIntoMeal$', () => {
  const buildStore = (): Store =>
    ({
      select: jest.fn(() => of('user-1')),
    }) as unknown as Store;

  it('reloads the meal log entries into the current meal', () => {
    const mealLogsService = {
      reloadMealIntoCurrentMeal: jest.fn(() => of(undefined)),
    } as unknown as MealLogsService;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    reloadMealLogIntoMeal$(
      actions$.asObservable(),
      mealLogsService,
      buildStore(),
    ).subscribe((action) => results.push(action));

    actions$.next(
      HistoryPageComponentActions.reloadMealLogIntoMealClicked({
        mealLog: createMealLog(),
      }),
    );

    expect(mealLogsService.reloadMealIntoCurrentMeal).toHaveBeenCalledWith({
      uid: 'user-1',
      mealEntries: [{ productId: 'p1', name: 'Pasta', carbs: 50, amount: 100 }],
    });
    expect(results).toEqual([MealLogsApiActions.mealLogReloadedIntoMeal()]);
  });

  it('ignores insulin doses', () => {
    const mealLogsService = {
      reloadMealIntoCurrentMeal: jest.fn(() => of(undefined)),
    } as unknown as MealLogsService;

    const actions$ = new Subject<Action>();
    reloadMealLogIntoMeal$(
      actions$.asObservable(),
      mealLogsService,
      buildStore(),
    ).subscribe();

    actions$.next(
      HistoryPageComponentActions.reloadMealLogIntoMealClicked({
        mealLog: createDose(),
      }),
    );

    expect(mealLogsService.reloadMealIntoCurrentMeal).not.toHaveBeenCalled();
  });

  it('dispatches mealLogReloadIntoMealFailed when reload fails', () => {
    const mealLogsService = {
      reloadMealIntoCurrentMeal: jest.fn(() =>
        throwError(() => new Error('boom')),
      ),
    } as unknown as MealLogsService;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    reloadMealLogIntoMeal$(
      actions$.asObservable(),
      mealLogsService,
      buildStore(),
    ).subscribe((action) => results.push(action));

    actions$.next(
      HistoryPageComponentActions.reloadMealLogIntoMealClicked({
        mealLog: createMealLog(),
      }),
    );

    expect(results).toEqual([
      MealLogsApiActions.mealLogReloadIntoMealFailed({
        error: expect.any(Error),
      }),
    ]);
  });
});

describe('showReloadIntoMealSuccessfulSnackbar$', () => {
  const buildSnackBar = () => {
    const afterDismissed = jest.fn();
    const snackBar = {
      open: jest.fn(() => ({
        afterOpened: () => of(void 0),
        afterDismissed,
      })),
    } as unknown as jest.Mocked<MatSnackBar>;
    return { snackBar, afterDismissed };
  };

  it('shows the success snackbar with a Go to Current Meal action', () => {
    const { snackBar, afterDismissed } = buildSnackBar();
    afterDismissed.mockReturnValue(of({ dismissedByAction: false }));

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    showReloadIntoMealSuccessfulSnackbar$(
      actions$.asObservable(),
      snackBar,
    ).subscribe((action) => results.push(action));

    actions$.next(MealLogsApiActions.mealLogReloadedIntoMeal());

    expect(snackBar.open).toHaveBeenCalledWith(
      'The meal was loaded into the current meal.',
      'Go to Current Meal',
    );
    expect(results).toEqual([
      MealLogsSnackBarActions.showReloadIntoMealSnackbarSuccessful(),
    ]);
  });

  it('dispatches goToCurrentMealClicked when the action is pressed', () => {
    const { snackBar, afterDismissed } = buildSnackBar();
    afterDismissed.mockReturnValue(of({ dismissedByAction: true }));

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    showReloadIntoMealSuccessfulSnackbar$(
      actions$.asObservable(),
      snackBar,
    ).subscribe((action) => results.push(action));

    actions$.next(MealLogsApiActions.mealLogReloadedIntoMeal());

    expect(results).toContainEqual(
      MealLogsSnackBarActions.goToCurrentMealClicked(),
    );
  });

  it('does not show the snackbar for other actions', () => {
    const { snackBar } = buildSnackBar();

    const actions$ = new Subject<Action>();
    showReloadIntoMealSuccessfulSnackbar$(
      actions$.asObservable(),
      snackBar,
    ).subscribe();

    actions$.next(
      MealLogsApiActions.mealLogReloadIntoMealFailed({ error: 'x' }),
    );

    expect(snackBar.open).not.toHaveBeenCalled();
  });
});

describe('showReloadIntoMealFailedSnackbar$', () => {
  it('shows the failure snackbar', () => {
    const snackBar = {
      open: jest.fn(() => ({ afterOpened: () => of(void 0) })),
    } as unknown as jest.Mocked<MatSnackBar>;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    showReloadIntoMealFailedSnackbar$(
      actions$.asObservable(),
      snackBar,
    ).subscribe((action) => results.push(action));

    actions$.next(
      MealLogsApiActions.mealLogReloadIntoMealFailed({ error: 'boom' }),
    );

    expect(snackBar.open).toHaveBeenCalledWith(
      'The meal could not be loaded into the current meal.',
    );
    expect(results).toEqual([
      MealLogsSnackBarActions.showReloadIntoMealSnackbarFailed(),
    ]);
  });
});

describe('navigateToCurrentMeal$', () => {
  it('navigates to the current meal page', () => {
    const router = { navigate: jest.fn(() => of(true)) } as unknown as Router;

    const actions$ = new Subject<Action>();
    navigateToCurrentMeal$(actions$.asObservable(), router).subscribe();

    actions$.next(MealLogsSnackBarActions.goToCurrentMealClicked());

    expect(router.navigate).toHaveBeenCalledWith(['app', 'current-meal']);
  });
});
