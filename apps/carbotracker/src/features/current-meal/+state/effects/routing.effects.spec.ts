import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { provideMockActions } from '@ngrx/effects/testing';
import { Action } from '@ngrx/store';
import { provideMockStore } from '@ngrx/store/testing';
import { of, Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { CurrentMealApiActions } from '../actions/api.actions';
import {
  CreateMealEntryPageComponentActions,
  EditMealEntryPageComponentActions,
} from '../actions/component.actions';
import { CurrentMealRouterEffectsActions } from '../actions/routing.actions';
import { navigateToCurrentMeal$ } from './routing.effects';

describe('navigateToCurrentMeal$', () => {
  let actions$: Subject<Action>;
  let router: jest.Mocked<Router>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    router = {
      navigate: jest.fn(() => of(true)),
    } as unknown as jest.Mocked<Router>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore(),
        { provide: Router, useValue: router },
      ],
    });
  });

  it('navigates to the current meal page after a meal entry is added successfully', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      navigateToCurrentMeal$().pipe(take(1)).subscribe((action) => results.push(action)),
    );

    actions$.next(CurrentMealApiActions.addMealEntrySuccessful());

    expect(router.navigate).toHaveBeenCalledWith(['app', 'current-meal']);
    expect(results).toEqual([
      CurrentMealRouterEffectsActions.navigationToCurrentMealPageSuccessful(),
    ]);
  });

  it('does not navigate on the create meal entry page save click', () => {
    TestBed.runInInjectionContext(() => navigateToCurrentMeal$().pipe(take(1)).subscribe());

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
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      navigateToCurrentMeal$().pipe(take(1)).subscribe((action) => results.push(action)),
    );

    actions$.next(EditMealEntryPageComponentActions.goBackIconClicked());

    expect(router.navigate).toHaveBeenCalledWith(['app', 'current-meal']);
    expect(results).toEqual([
      CurrentMealRouterEffectsActions.navigationToCurrentMealPageSuccessful(),
    ]);
  });
});
