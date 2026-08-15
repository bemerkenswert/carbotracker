import { Action, Store } from '@ngrx/store';
import { of, Subject, throwError } from 'rxjs';
import { authFeature } from '../../../features/auth/+state/auth.store';
import { CurrentMeal, MealEntry } from '../current-meal.model';
import { CurrentMealService } from '../services/current-meal.service';
import { CurrentMealApiActions } from './actions/api.actions';
import {
  CreateMealEntryPageComponentActions,
  CurrentMealPageComponentActions,
} from './actions/component.actions';
import { currentMealFeature } from './current-meal.store';
import {
  addMealEntryToCurrentMeal,
  removeAllMealEntriesOfCurrentMeal$,
} from './effects/api.effects';

const mealEntry: MealEntry = {
  productId: 'p1',
  name: 'spaghetti',
  carbs: 25,
  amount: 250,
};

const product = {
  id: 'p1',
  name: 'spaghetti',
  creator: 'user-a',
  carbs: 25,
};

const currentMeal: CurrentMeal = { mealEntries: [mealEntry] };

const buildStore = (): Store =>
  ({
    select: jest.fn((selector) => {
      if (selector === authFeature.selectUserId) {
        return of('user-1');
      }
      if (selector === currentMealFeature.selectCurrentMeal) {
        return of(currentMeal);
      }
      return of(null);
    }),
  }) as unknown as Store;

describe('removeAllMealEntriesOfCurrentMeal$', () => {
  it('dispatches clearCurrentMealSuccessful when the meal is cleared', () => {
    const currentMealService = {
      cleanAllMealEntries: jest.fn(() => of(undefined)),
    } as unknown as CurrentMealService;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    removeAllMealEntriesOfCurrentMeal$(
      actions$.asObservable(),
      currentMealService,
      buildStore(),
    ).subscribe((action) => results.push(action));

    actions$.next(CurrentMealPageComponentActions.clearCurrentMealClicked());

    expect(currentMealService.cleanAllMealEntries).toHaveBeenCalledWith({
      uid: 'user-1',
    });
    expect(results).toEqual([
      CurrentMealApiActions.clearCurrentMealSuccessful(),
    ]);
  });

  it('dispatches clearCurrentMealFailed when clearing fails', () => {
    const currentMealService = {
      cleanAllMealEntries: jest.fn(() => throwError(() => new Error('boom'))),
    } as unknown as CurrentMealService;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    removeAllMealEntriesOfCurrentMeal$(
      actions$.asObservable(),
      currentMealService,
      buildStore(),
    ).subscribe((action) => results.push(action));

    actions$.next(CurrentMealPageComponentActions.clearCurrentMealClicked());

    expect(results).toEqual([
      CurrentMealApiActions.clearCurrentMealFailed({
        error: expect.any(Error),
      }),
    ]);
  });
});

describe('addMealEntryToCurrentMeal', () => {
  it('dispatches addMealEntrySuccessful when the entry is added', () => {
    const currentMealService = {
      addMealEntry: jest.fn(() => of(undefined)),
    } as unknown as CurrentMealService;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    addMealEntryToCurrentMeal(
      actions$.asObservable(),
      currentMealService,
      buildStore(),
    ).subscribe((action) => results.push(action));

    actions$.next(
      CreateMealEntryPageComponentActions.saveClicked({
        product,
        amount: 250,
      }),
    );

    expect(currentMealService.addMealEntry).toHaveBeenCalledWith({
      currentMeal,
      mealEntry,
      uid: 'user-1',
    });
    expect(results).toEqual([CurrentMealApiActions.addMealEntrySuccessful()]);
  });

  it('dispatches addMealEntryFailed when adding fails', () => {
    const currentMealService = {
      addMealEntry: jest.fn(() => throwError(() => new Error('boom'))),
    } as unknown as CurrentMealService;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    addMealEntryToCurrentMeal(
      actions$.asObservable(),
      currentMealService,
      buildStore(),
    ).subscribe((action) => results.push(action));

    actions$.next(
      CreateMealEntryPageComponentActions.saveClicked({
        product,
        amount: 250,
      }),
    );

    expect(results).toEqual([
      CurrentMealApiActions.addMealEntryFailed({ error: expect.any(Error) }),
    ]);
  });
});
