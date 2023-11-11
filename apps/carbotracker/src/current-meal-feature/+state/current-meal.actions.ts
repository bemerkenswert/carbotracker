import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { CurrentMeal, MealEntry } from '../current-meal.model';
import { Product } from '../../products-feature/product.model';

export const CurrentMealPageComponentActions = createActionGroup({
  source: 'Current Meal | Current Meal Page Component',
  events: {
    'Entered Current Meal Page': emptyProps(),
    'Left Current Meal Page': emptyProps(),
    'Meal Entry Clicked': props<{ mealEntry: MealEntry }>(),
    'Add Clicked': emptyProps(),
  },
});

export const CreateMealEntryPageComponentActions = createActionGroup({
  source: 'Current Meal | Create Meal Entry Page Component',
  events: {
    'Entered Create Meal Entry Page': emptyProps(),
    'Save Clicked': props<{ mealEntry: MealEntry }>(),
    'Product Search Term Changed': props<{ productSearchTerm: string }>(),
  },
});

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
  },
});
