import { Action, Store } from '@ngrx/store';
import { of, Subject } from 'rxjs';
import { authFeature } from '../../features/auth/+state/auth.store';
import { SavedMealNameDialogService } from '../../saved-meals-feature/saved-meal-name-dialog/saved-meal-name-dialog.service';
import { SavedMealsService } from '../../saved-meals-feature/services/saved-meals.service';
import { CurrentMeal } from '../current-meal.model';
import { CurrentMealPageComponentActions } from './current-meal.actions';
import { saveCurrentMealAsSavedMeal } from './current-meal.effects';
import { currentMealFeature } from './current-meal.feature';

describe('saveCurrentMealAsSavedMeal', () => {
  const currentMeal: CurrentMeal = {
    mealEntries: [
      { productId: 'p1', name: 'spaghetti', carbs: 25, amount: 250 },
    ],
  };

  const buildStore = (isEmpty: boolean): Store =>
    ({
      select: jest.fn((selector) => {
        if (selector === authFeature.selectUserId) {
          return of('user-1');
        }
        if (selector === currentMealFeature.selectCurrentMeal) {
          return of(currentMeal);
        }
        if (selector === currentMealFeature.selectCurrentMealIsEmpty) {
          return of(isEmpty);
        }
        return of(null);
      }),
    }) as unknown as Store;

  const buildMocks = () => {
    const savedMealsService = {
      saveCurrentMeal: jest.fn(() => of(undefined)),
    } as unknown as SavedMealsService;
    const nameDialogService = {
      open: jest.fn(),
    } as unknown as jest.Mocked<SavedMealNameDialogService>;
    return { savedMealsService, nameDialogService };
  };

  it('opens the name dialog and saves when the user confirms with a name', () => {
    const { savedMealsService, nameDialogService } = buildMocks();
    nameDialogService.open.mockReturnValue(of('Steffens Pasta Dream'));

    const actions$ = new Subject<Action>();
    const store = buildStore(false);
    const effect$ = saveCurrentMealAsSavedMeal(
      actions$.asObservable(),
      store,
      savedMealsService,
      nameDialogService,
    );
    effect$.subscribe();

    actions$.next(CurrentMealPageComponentActions.saveCurrentMealClicked());

    expect(nameDialogService.open).toHaveBeenCalled();
    expect(savedMealsService.saveCurrentMeal).toHaveBeenCalledWith({
      uid: 'user-1',
      currentMeal,
      name: 'Steffens Pasta Dream',
    });
  });

  it('does not open the dialog or save when the user aborts it', () => {
    const { savedMealsService, nameDialogService } = buildMocks();
    nameDialogService.open.mockReturnValue(of(undefined));

    const actions$ = new Subject<Action>();
    const store = buildStore(false);
    const effect$ = saveCurrentMealAsSavedMeal(
      actions$.asObservable(),
      store,
      savedMealsService,
      nameDialogService,
    );
    effect$.subscribe();

    actions$.next(CurrentMealPageComponentActions.saveCurrentMealClicked());

    expect(nameDialogService.open).toHaveBeenCalled();
    expect(savedMealsService.saveCurrentMeal).not.toHaveBeenCalled();
  });

  it('does not save when the current meal is empty', () => {
    const { savedMealsService, nameDialogService } = buildMocks();

    const actions$ = new Subject<Action>();
    const store = buildStore(true);
    const effect$ = saveCurrentMealAsSavedMeal(
      actions$.asObservable(),
      store,
      savedMealsService,
      nameDialogService,
    );
    effect$.subscribe();

    actions$.next(CurrentMealPageComponentActions.saveCurrentMealClicked());

    expect(nameDialogService.open).not.toHaveBeenCalled();
    expect(savedMealsService.saveCurrentMeal).not.toHaveBeenCalled();
  });
});
