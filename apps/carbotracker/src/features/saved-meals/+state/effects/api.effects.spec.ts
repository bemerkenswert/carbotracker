import { Action } from '@ngrx/store';
import { of, Subject, throwError } from 'rxjs';
import { take } from 'rxjs/operators';
import { SavedMeal } from '../../saved-meal.model';
import { SavedMealsService } from '../../services/saved-meals.service';
import { SavedMealsApiActions } from '../actions/api.actions';
import { DeleteSavedMealConfirmationDialogActions } from '../actions/dialog.actions';
import { deleteSavedMeal$ } from './api.effects';

describe('deleteSavedMeal$', () => {
  const savedMeal: SavedMeal = {
    id: 'm1',
    name: 'Steffens Pasta Dream',
    createdAt: new Date('2024-06-01'),
    mealEntries: [],
  };

  const buildEffect = (serviceResult: unknown) => {
    const savedMealsService = {
      deleteSavedMeal: jest.fn(() => serviceResult),
    } as unknown as jest.Mocked<SavedMealsService>;
    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    deleteSavedMeal$(actions$.asObservable(), savedMealsService).pipe(take(1)).subscribe(
      (action) => results.push(action),
    );
    return { savedMealsService, actions$, results };
  };

  it('deletes the saved meal when the dialog is confirmed', () => {
    const { savedMealsService, actions$, results } = buildEffect(of(undefined));

    actions$.next(
      DeleteSavedMealConfirmationDialogActions.confirmClicked({ savedMeal }),
    );

    expect(savedMealsService.deleteSavedMeal).toHaveBeenCalledWith('m1');
    expect(results).toEqual([
      SavedMealsApiActions.deletingSavedMealSuccessful(),
    ]);
  });

  it('does not delete when the dialog is aborted', () => {
    const { savedMealsService, actions$, results } = buildEffect(of(undefined));

    actions$.next(DeleteSavedMealConfirmationDialogActions.abortClicked());

    expect(savedMealsService.deleteSavedMeal).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });

  it('dispatches deletingSavedMealFailed when deleting fails', () => {
    const { savedMealsService, actions$, results } = buildEffect(
      throwError(() => new Error('boom')),
    );

    actions$.next(
      DeleteSavedMealConfirmationDialogActions.confirmClicked({ savedMeal }),
    );

    expect(savedMealsService.deleteSavedMeal).toHaveBeenCalledWith('m1');
    expect(results).toEqual([
      SavedMealsApiActions.deletingSavedMealFailed({
        error: expect.any(Error),
      }),
    ]);
  });
});
