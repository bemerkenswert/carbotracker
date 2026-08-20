import { ConfirmationDialogService } from '@carbotracker/ui';
import { Action } from '@ngrx/store';
import { of, Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { SavedMeal } from '../../saved-meal.model';
import { SavedMealPageComponentActions } from '../actions/component.actions';
import { DeleteSavedMealConfirmationDialogActions } from '../actions/dialog.actions';
import { showDeleteConfirmationDialog$ } from './dialog.effects';

describe('showDeleteConfirmationDialog$', () => {
  const savedMeal: SavedMeal = {
    id: 'm1',
    name: 'Steffens Pasta Dream',
    createdAt: new Date('2024-06-01'),
    mealEntries: [],
  };

  const buildEffect = () => {
    const confirmationDialogService = {
      openDeleteConfirmationDialog: jest.fn(),
    } as unknown as jest.Mocked<ConfirmationDialogService>;
    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    showDeleteConfirmationDialog$(
      actions$.asObservable(),
      confirmationDialogService,
    )
      .pipe(take(1))
      .subscribe((action) => results.push(action));
    return { confirmationDialogService, actions$, results };
  };

  it('opens the delete confirmation dialog and dispatches confirmClicked when confirmed', () => {
    const { confirmationDialogService, actions$, results } = buildEffect();
    confirmationDialogService.openDeleteConfirmationDialog.mockReturnValue(
      of({ confirmed: true }),
    );

    actions$.next(SavedMealPageComponentActions.deleteClicked({ savedMeal }));

    expect(
      confirmationDialogService.openDeleteConfirmationDialog,
    ).toHaveBeenCalledWith('Steffens Pasta Dream');
    expect(results).toEqual([
      DeleteSavedMealConfirmationDialogActions.confirmClicked({ savedMeal }),
    ]);
  });

  it('dispatches abortClicked when the user aborts the dialog', () => {
    const { confirmationDialogService, actions$, results } = buildEffect();
    confirmationDialogService.openDeleteConfirmationDialog.mockReturnValue(
      of({ confirmed: false }),
    );

    actions$.next(SavedMealPageComponentActions.deleteClicked({ savedMeal }));

    expect(results).toEqual([
      DeleteSavedMealConfirmationDialogActions.abortClicked(),
    ]);
  });

  it('does not open the dialog for other actions', () => {
    const { confirmationDialogService, actions$, results } = buildEffect();

    actions$.next(
      SavedMealPageComponentActions.selectedSavedMealChanged({
        selectedSavedMealId: 'm1',
      }),
    );

    expect(
      confirmationDialogService.openDeleteConfirmationDialog,
    ).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });
});
