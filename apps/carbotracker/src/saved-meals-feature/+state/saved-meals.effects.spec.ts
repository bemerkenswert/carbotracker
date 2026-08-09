import { Router } from '@angular/router';
import { ConfirmationDialogService } from '@carbotracker/ui';
import { Action, Store } from '@ngrx/store';
import { of, Subject } from 'rxjs';
import { authFeature } from '../../features/auth/+state/auth.store';
import { SavedMeal } from '../saved-meal.model';
import { SavedMealsService } from '../services/saved-meals.service';
import { SavedMealPageComponentActions } from './saved-meals.actions';
import { deleteSavedMeal } from './saved-meals.effects';

describe('deleteSavedMeal', () => {
  const savedMeal: SavedMeal = {
    id: 'm1',
    name: 'Steffens Pasta Dream',
    createdAt: new Date('2024-06-01'),
    mealEntries: [],
  };

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
    const savedMealsService = {
      deleteSavedMeal: jest.fn(() => of(undefined)),
    } as unknown as SavedMealsService;
    const confirmationDialogService = {
      openDeleteConfirmationDialog: jest.fn(),
    } as unknown as jest.Mocked<ConfirmationDialogService>;
    const router = {
      navigate: jest.fn(() => Promise.resolve(true)),
    } as unknown as Router;
    return { savedMealsService, confirmationDialogService, router };
  };

  it('deletes the saved meal when the user confirms the dialog', () => {
    const { savedMealsService, confirmationDialogService, router } =
      buildMocks();
    confirmationDialogService.openDeleteConfirmationDialog.mockReturnValue(
      of({ confirmed: true }),
    );

    const actions$ = new Subject<Action>();
    const effect$ = deleteSavedMeal(
      actions$.asObservable(),
      buildStore(),
      savedMealsService,
      confirmationDialogService,
      router,
    );
    effect$.subscribe();

    actions$.next(SavedMealPageComponentActions.deleteClicked({ savedMeal }));

    expect(
      confirmationDialogService.openDeleteConfirmationDialog,
    ).toHaveBeenCalledWith('Steffens Pasta Dream');
    expect(savedMealsService.deleteSavedMeal).toHaveBeenCalledWith('m1');
    expect(router.navigate).toHaveBeenCalledWith(['app', 'saved-meals']);
  });

  it('does not delete when the user aborts the dialog', () => {
    const { savedMealsService, confirmationDialogService, router } =
      buildMocks();
    confirmationDialogService.openDeleteConfirmationDialog.mockReturnValue(
      of({ confirmed: false }),
    );

    const actions$ = new Subject<Action>();
    const effect$ = deleteSavedMeal(
      actions$.asObservable(),
      buildStore(),
      savedMealsService,
      confirmationDialogService,
      router,
    );
    effect$.subscribe();

    actions$.next(SavedMealPageComponentActions.deleteClicked({ savedMeal }));

    expect(savedMealsService.deleteSavedMeal).not.toHaveBeenCalled();
    expect(router.navigate).not.toHaveBeenCalled();
  });
});
