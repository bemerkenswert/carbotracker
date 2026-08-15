import { Action } from '@ngrx/store';
import { Router } from '@angular/router';
import { Subject, of } from 'rxjs';
import { CurrentMealApiActions } from '../actions/api.actions';
import {
  EditMealEntryPageComponentActions,
  CreateMealEntryPageComponentActions,
} from '../actions/component.actions';
import { CurrentMealRouterEffectsActions } from '../actions/routing.actions';
import { navigateToCurrentMeal$ } from './routing.effects';

const buildRouter = (): Router =>
  ({
    navigate: jest.fn(() => of(true)),
  }) as unknown as Router;

describe('navigateToCurrentMeal$', () => {
  it('navigates to the current meal page after a meal entry is added successfully', () => {
    const router = buildRouter();
    const actions$ = new Subject<Action>();
    const results: Action[] = [];

    navigateToCurrentMeal$(actions$.asObservable(), router).subscribe(
      (action) => results.push(action),
    );

    actions$.next(CurrentMealApiActions.addMealEntrySuccessful());

    expect(router.navigate).toHaveBeenCalledWith(['app', 'current-meal']);
    expect(results).toEqual([
      CurrentMealRouterEffectsActions.navigationToCurrentMealPageSuccessful(),
    ]);
  });

  it('does not navigate on the create meal entry page save click', () => {
    const router = buildRouter();
    const actions$ = new Subject<Action>();

    navigateToCurrentMeal$(actions$.asObservable(), router).subscribe();

    actions$.next(
      CreateMealEntryPageComponentActions.saveClicked({
        product: {
          id: 'p1',
          name: 'spaghetti',
          creator: 'user-a',
          carbs: 25,
        },
        amount: 250,
      }),
    );

    expect(router.navigate).not.toHaveBeenCalled();
  });

  it('navigates to the current meal page on edit meal entry page actions', () => {
    const router = buildRouter();
    const actions$ = new Subject<Action>();
    const results: Action[] = [];

    navigateToCurrentMeal$(actions$.asObservable(), router).subscribe(
      (action) => results.push(action),
    );

    actions$.next(EditMealEntryPageComponentActions.goBackIconClicked());

    expect(router.navigate).toHaveBeenCalledWith(['app', 'current-meal']);
    expect(results).toEqual([
      CurrentMealRouterEffectsActions.navigationToCurrentMealPageSuccessful(),
    ]);
  });
});
