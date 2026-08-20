import { Router } from '@angular/router';
import { Action } from '@ngrx/store';
import { of, Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { SavedMeal } from '../../saved-meal.model';
import { SavedMealsApiActions } from '../actions/api.actions';
import { SavedMealsPageComponentActions } from '../actions/component.actions';
import { SavedMealsRouterEffectsActions } from '../actions/routing.actions';
import {
  navigateToSavedMeal$,
  navigateToSavedMealsPage$,
} from './routing.effects';

const savedMeal: SavedMeal = {
  id: 'm1',
  name: 'Steffens Pasta Dream',
  createdAt: new Date('2024-06-01'),
  mealEntries: [],
};

const buildRouter = (): Router =>
  ({
    navigate: jest.fn(() => of(true)),
  }) as unknown as Router;

describe('navigateToSavedMeal$', () => {
  it('navigates to the saved meal page when a saved meal is clicked', () => {
    const router = buildRouter();
    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    navigateToSavedMeal$(actions$.asObservable(), router).pipe(take(1)).subscribe((action) =>
      results.push(action),
    );

    actions$.next(
      SavedMealsPageComponentActions.savedMealClicked({ savedMeal }),
    );

    expect(router.navigate).toHaveBeenCalledWith(['app', 'saved-meals', 'm1']);
    expect(results).toEqual([
      SavedMealsRouterEffectsActions.navigationToSavedMealPageSuccessful(),
    ]);
  });

  it('does not navigate for other actions', () => {
    const router = buildRouter();
    const actions$ = new Subject<Action>();
    navigateToSavedMeal$(actions$.asObservable(), router).pipe(take(1)).subscribe();

    actions$.next(SavedMealsPageComponentActions.enteredSavedMealsPage());

    expect(router.navigate).not.toHaveBeenCalled();
  });
});

describe('navigateToSavedMealsPage$', () => {
  it('navigates to the saved meals page after the saved meal is deleted', () => {
    const router = buildRouter();
    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    navigateToSavedMealsPage$(actions$.asObservable(), router).pipe(take(1)).subscribe(
      (action) => results.push(action),
    );

    actions$.next(SavedMealsApiActions.deletingSavedMealSuccessful());

    expect(router.navigate).toHaveBeenCalledWith(['app', 'saved-meals']);
    expect(results).toEqual([
      SavedMealsRouterEffectsActions.navigationToSavedMealsPageSuccessful(),
    ]);
  });

  it('does not navigate when deleting the saved meal fails', () => {
    const router = buildRouter();
    const actions$ = new Subject<Action>();
    navigateToSavedMealsPage$(actions$.asObservable(), router).pipe(take(1)).subscribe();

    actions$.next(
      SavedMealsApiActions.deletingSavedMealFailed({ error: 'boom' }),
    );

    expect(router.navigate).not.toHaveBeenCalled();
  });
});
