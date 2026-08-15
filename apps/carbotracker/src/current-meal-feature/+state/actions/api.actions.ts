import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { Product } from '../../../features/products/product.model';
import { CurrentMeal } from '../../current-meal.model';

export const ProductsApiActions = createActionGroup({
  source: 'Current Meal | Products Api',
  events: {
    'Products Collection Changed': props<{ products: Product[] }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Products Stream': emptyProps(),
  },
});

export const CurrentMealApiActions = createActionGroup({
  source: 'Current Meal | Current Meal Api',
  events: {
    'Current Meal Collection Changed': props<{ currentMeal: CurrentMeal }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Current Meal Stream': emptyProps(),
    'Add Meal Entry Successful': emptyProps(),
    'Add Meal Entry Failed': props<{ error: unknown }>(),
    'Clear Current Meal Successful': emptyProps(),
    'Clear Current Meal Failed': props<{ error: unknown }>(),
    'Save Current Meal Successful': emptyProps(),
    'Save Current Meal Failed': props<{ error: unknown }>(),
  },
});
