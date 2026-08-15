import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { CurrentMeal } from '../../current-meal.model';

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
