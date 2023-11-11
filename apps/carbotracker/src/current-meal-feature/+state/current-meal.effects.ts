import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, concatLatestFrom, createEffect, ofType } from '@ngrx/effects';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Store } from '@ngrx/store';
import { concatMap, exhaustMap, filter, from, of, switchMap, tap } from 'rxjs';
import { authFeature } from '../../auth-feature/auth.reducer';
import { CurrentMealService } from '../services/current-meal.service';
import { ProductsService } from '../services/products.service';
import {
  CreateMealEntryPageComponentActions,
  CurrentMealPageComponentActions,
} from './current-meal.actions';
import { currentMealFeature } from './current-meal.feature';

export const navigateToCreateMealEntry$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(CurrentMealPageComponentActions.addClicked),
      exhaustMap(() => from(router.navigate(['app', 'current-meal', 'create'])))
    ),
  { dispatch: false, functional: true }
);

export const addMealEntryToCurrentMeal = createEffect(
  (
    actions$ = inject(Actions),
    currentMealService = inject(CurrentMealService),
    store = inject(Store)
  ) =>
    actions$.pipe(
      ofType(CreateMealEntryPageComponentActions.saveClicked),
      concatLatestFrom(() => [
        store.select(authFeature.selectUserId),
        store.select(currentMealFeature.selectCurrentMeal),
      ]),
      concatMap(([{ mealEntry }, uid, currentMeal]) => {
        if (uid) {
          return currentMealService.addMealEntry({
            currentMeal,
            mealEntry,
            uid,
          });
        } else {
          return of();
        }
      })
    ),
  { functional: true, dispatch: false }
);

export const startStreamingProducts$ = createEffect(
  (
    actions$ = inject(Actions),
    productsService = inject(ProductsService),
    store = inject(Store)
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(({ payload }) =>
        payload.event.urlAfterRedirects.startsWith('/app/current-meal/create')
      ),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          productsService.subscribeToOwnProducts({ uid });
        }
      })
    ),
  { dispatch: false, functional: true }
);

export const stopStreamingProducts$ = createEffect(
  (actions$ = inject(Actions), productsService = inject(ProductsService)) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(
        ({ payload }) =>
          !payload.event.urlAfterRedirects.startsWith(
            '/app/current-meal/create'
          )
      ),
      tap(() => {
        productsService.unsubscribeFromOwnProducts();
      })
    ),
  { dispatch: false, functional: true }
);

export const startStreamingCurrentMeal$ = createEffect(
  (
    actions$ = inject(Actions),
    currentMealService = inject(CurrentMealService),
    store = inject(Store)
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(({ payload }) =>
        payload.event.urlAfterRedirects.startsWith('/app/current-meal')
      ),
      switchMap(() => store.select(authFeature.selectUserId)),
      tap((uid) => {
        if (uid) {
          currentMealService.subscribeToOwnCurrentMeal({ uid });
        }
      })
    ),
  { dispatch: false, functional: true }
);

export const stopStreamingCurrentMeal$ = createEffect(
  (
    actions$ = inject(Actions),
    currentMealService = inject(CurrentMealService)
  ) =>
    actions$.pipe(
      ofType(routerNavigatedAction),
      filter(
        ({ payload }) =>
          !payload.event.urlAfterRedirects.startsWith('/app/current-meal')
      ),
      tap(() => {
        currentMealService.unsubscribeFromOwnCurrentMeal();
      })
    ),
  { dispatch: false, functional: true }
);
