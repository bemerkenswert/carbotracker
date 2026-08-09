import { Action, Store } from '@ngrx/store';
import { of, Subject, throwError } from 'rxjs';
import { authFeature } from '../../features/auth/+state/auth.store';
import { SavedMealNameDialogService } from '../../saved-meals-feature/saved-meal-name-dialog/saved-meal-name-dialog.service';
import { SavedMealsService } from '../../saved-meals-feature/services/saved-meals.service';
import { CurrentMeal } from '../current-meal.model';
import { CurrentMealApiActions } from './actions/api.actions';
import { CurrentMealPageComponentActions } from './actions/component.actions';
import { saveCurrentMealAsSavedMeal } from './effects/api.effects';
import { currentMealFeature } from './current-meal.feature';

describe('saveCurrentMealAsSavedMeal', () => {
  const currentMeal: CurrentMeal = {
    mealEntries: [
      { productId: 'p1', name: 'spaghetti', carbs: 25, amount: 250 },
    ],
  };

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

  const buildMocks = () => {
    const savedMealsService = {
      saveCurrentMeal: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<SavedMealsService>;
    const nameDialogService = {
      open: jest.fn(),
    } as unknown as jest.Mocked<SavedMealNameDialogService>;
    return { savedMealsService, nameDialogService };
  };

  it('opens the name dialog and saves when the user confirms with a name', () => {
    const { savedMealsService, nameDialogService } = buildMocks();
    nameDialogService.open.mockReturnValue(
      of({ cancelled: false, name: 'Steffens Pasta Dream' }),
    );

    const actions$ = new Subject<Action>();
    const store = buildStore();
    const results: Action[] = [];
    saveCurrentMealAsSavedMeal(
      actions$.asObservable(),
      store,
      savedMealsService,
      nameDialogService,
    ).subscribe((action) => results.push(action));

    actions$.next(CurrentMealPageComponentActions.saveCurrentMealClicked());

    expect(nameDialogService.open).toHaveBeenCalled();
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
    const { savedMealsService, nameDialogService } = buildMocks();
    nameDialogService.open.mockReturnValue(of({ cancelled: true }));

    const actions$ = new Subject<Action>();
    const store = buildStore();
    saveCurrentMealAsSavedMeal(
      actions$.asObservable(),
      store,
      savedMealsService,
      nameDialogService,
    ).subscribe();

    actions$.next(CurrentMealPageComponentActions.saveCurrentMealClicked());

    expect(nameDialogService.open).toHaveBeenCalled();
    expect(savedMealsService.saveCurrentMeal).not.toHaveBeenCalled();
  });

  it('dispatches saveCurrentMealFailed when saving fails', () => {
    const { savedMealsService, nameDialogService } = buildMocks();
    nameDialogService.open.mockReturnValue(
      of({ cancelled: false, name: 'Steffens Pasta Dream' }),
    );
    savedMealsService.saveCurrentMeal.mockReturnValue(
      throwError(() => new Error('boom')),
    );

    const actions$ = new Subject<Action>();
    const store = buildStore();
    const results: Action[] = [];
    saveCurrentMealAsSavedMeal(
      actions$.asObservable(),
      store,
      savedMealsService,
      nameDialogService,
    ).subscribe((action) => results.push(action));

    actions$.next(CurrentMealPageComponentActions.saveCurrentMealClicked());

    expect(results).toEqual([
      CurrentMealApiActions.saveCurrentMealFailed({ error: expect.any(Error) }),
    ]);
  });
});
