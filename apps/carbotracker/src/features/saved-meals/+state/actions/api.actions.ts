import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { SavedMeal } from '../../saved-meal.model';

export const SavedMealsApiActions = createActionGroup({
  source: 'Saved Meals | Saved Meals Api',
  events: {
    'Saved Meals Collection Changed': props<{ savedMeals: SavedMeal[] }>(),
    'Deleting Saved Meal Successful': emptyProps(),
    'Deleting Saved Meal Failed': props<{ error: unknown }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Saved Meals Stream': emptyProps(),
  },
});
