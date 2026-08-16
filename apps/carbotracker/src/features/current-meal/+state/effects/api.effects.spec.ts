import { TestBed } from '@angular/core/testing';
import { provideMockActions } from '@ngrx/effects/testing';
import { Action } from '@ngrx/store';
import { provideMockStore } from '@ngrx/store/testing';
import { of, Subject, throwError } from 'rxjs';
import { authFeature } from '../../../auth/+state/auth.store';
import { SavedMealNameDialogService } from '../../../saved-meals/saved-meal-name-dialog/saved-meal-name-dialog.service';
import { SavedMealsService } from '../../../saved-meals/services/saved-meals.service';
import { CurrentMeal, MealEntry } from '../../current-meal.model';
import { CurrentMealService } from '../../services/current-meal.service';
import { CurrentMealApiActions } from '../actions/api.actions';
import {
  CreateMealEntryPageComponentActions,
  CurrentMealPageComponentActions,
} from '../actions/component.actions';
import { currentMealFeature } from '../current-meal.store';
import {
  addMealEntryToCurrentMeal,
  removeAllMealEntriesOfCurrentMeal$,
  saveCurrentMealAsSavedMeal,
} from './api.effects';

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

describe('saveCurrentMealAsSavedMeal', () => {
  let actions$: Subject<Action>;
  let savedMealsService: jest.Mocked<SavedMealsService>;
  let savedMealNameDialogService: jest.Mocked<SavedMealNameDialogService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    savedMealsService = {
      saveCurrentMeal: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<SavedMealsService>;
    savedMealNameDialogService = {
      open: jest.fn(() => of({ cancelled: true })),
    } as unknown as jest.Mocked<SavedMealNameDialogService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [
            { selector: authFeature.selectUserId, value: 'user-1' },
            {
              selector: currentMealFeature.selectCurrentMeal,
              value: currentMeal,
            },
          ],
        }),
        { provide: SavedMealsService, useValue: savedMealsService },
        {
          provide: SavedMealNameDialogService,
          useValue: savedMealNameDialogService,
        },
      ],
    });
  });

  it('opens the name dialog and saves when the user confirms with a name', () => {
    savedMealNameDialogService.open.mockReturnValue(
      of({ cancelled: false, name: 'Steffens Pasta Dream' }),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      saveCurrentMealAsSavedMeal().subscribe((action) => results.push(action)),
    );

    actions$.next(CurrentMealPageComponentActions.saveCurrentMealClicked());

    expect(savedMealsService.saveCurrentMeal).toHaveBeenCalledWith({
      uid: 'user-1',
      currentMeal,
      name: 'Steffens Pasta Dream',
    });
    expect(results).toEqual([
      CurrentMealApiActions.saveCurrentMealSuccessful(),
    ]);
  });

  it('does not save when the user cancels the dialog', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      saveCurrentMealAsSavedMeal().subscribe((action) => results.push(action)),
    );

    actions$.next(CurrentMealPageComponentActions.saveCurrentMealClicked());

    expect(savedMealsService.saveCurrentMeal).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });

  it('dispatches saveCurrentMealFailed when saving fails', () => {
    savedMealNameDialogService.open.mockReturnValue(
      of({ cancelled: false, name: 'Steffens Pasta Dream' }),
    );
    savedMealsService.saveCurrentMeal.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      saveCurrentMealAsSavedMeal().subscribe((action) => results.push(action)),
    );

    actions$.next(CurrentMealPageComponentActions.saveCurrentMealClicked());

    expect(results).toEqual([
      CurrentMealApiActions.saveCurrentMealFailed({ error: expect.any(Error) }),
    ]);
  });
});

describe('removeAllMealEntriesOfCurrentMeal$', () => {
  let actions$: Subject<Action>;
  let currentMealService: jest.Mocked<CurrentMealService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    currentMealService = {
      cleanAllMealEntries: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<CurrentMealService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [{ selector: authFeature.selectUserId, value: 'user-1' }],
        }),
        { provide: CurrentMealService, useValue: currentMealService },
      ],
    });
  });

  it('dispatches clearCurrentMealSuccessful when the meal is cleared', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      removeAllMealEntriesOfCurrentMeal$().subscribe((action) =>
        results.push(action),
      ),
    );

    actions$.next(CurrentMealPageComponentActions.clearCurrentMealClicked());

    expect(currentMealService.cleanAllMealEntries).toHaveBeenCalledWith({
      uid: 'user-1',
    });
    expect(results).toEqual([
      CurrentMealApiActions.clearCurrentMealSuccessful(),
    ]);
  });

  it('dispatches clearCurrentMealFailed when clearing fails', () => {
    currentMealService.cleanAllMealEntries.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      removeAllMealEntriesOfCurrentMeal$().subscribe((action) =>
        results.push(action),
      ),
    );

    actions$.next(CurrentMealPageComponentActions.clearCurrentMealClicked());

    expect(results).toEqual([
      CurrentMealApiActions.clearCurrentMealFailed({
        error: expect.any(Error),
      }),
    ]);
  });
});

describe('addMealEntryToCurrentMeal', () => {
  let actions$: Subject<Action>;
  let currentMealService: jest.Mocked<CurrentMealService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    currentMealService = {
      addMealEntry: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<CurrentMealService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [
            { selector: authFeature.selectUserId, value: 'user-1' },
            {
              selector: currentMealFeature.selectCurrentMeal,
              value: currentMeal,
            },
          ],
        }),
        { provide: CurrentMealService, useValue: currentMealService },
      ],
    });
  });

  it('dispatches addMealEntrySuccessful when the entry is added', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      addMealEntryToCurrentMeal().subscribe((action) => results.push(action)),
    );

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
    currentMealService.addMealEntry.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      addMealEntryToCurrentMeal().subscribe((action) => results.push(action)),
    );

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
