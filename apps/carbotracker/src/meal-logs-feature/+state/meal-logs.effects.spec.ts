import { Store } from '@ngrx/store';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Action } from '@ngrx/store';
import { of, Subject, throwError } from 'rxjs';
import { authFeature } from '../../features/auth/+state/auth.store';
import { InsulinDoseDialogService } from '../insulin-dose-dialog/insulin-dose-dialog.service';
import { MealLogsService } from '../services/meal-logs.service';
import { HistoryPageComponentActions } from './meal-logs.actions';
import {
  createInsulinDose$,
  startStreamingMealLogs$,
  stopStreamingMealLogs$,
} from './meal-logs.effects';
import { MealLogsApiActions } from './meal-logs.actions';

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
    effect$.subscribe();

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
    effect$.subscribe();

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
    effect$.subscribe();

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
    ).subscribe((action) => results.push(action));

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
    ).subscribe();

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
    ).subscribe((action) => results.push(action));

    actions$.next(HistoryPageComponentActions.logInsulinDoseClicked());

    expect(results).toEqual([
      MealLogsApiActions.insulinDoseCreationFailed({
        error: expect.any(Error),
      }),
    ]);
  });
});
