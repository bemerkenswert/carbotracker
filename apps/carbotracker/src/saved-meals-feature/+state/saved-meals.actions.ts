import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { SavedMeal } from '../saved-meal.model';

export const SavedMealsPageComponentActions = createActionGroup({
  source: 'Saved Meals | Saved Meals Page Component',
  events: {
    'Entered Saved Meals Page': emptyProps(),
    'Left Saved Meals Page': emptyProps(),
    'Saved Meal Clicked': props<{ savedMeal: SavedMeal }>(),
  },
});

export const SavedMealPageComponentActions = createActionGroup({
  source: 'Saved Meals | Saved Meal Page Component',
  events: {
    'Selected Saved Meal Changed': props<{ selectedSavedMealId: string }>(),
    'Delete Clicked': props<{ savedMeal: SavedMeal }>(),
    'Go Back Icon Clicked': emptyProps(),
  },
});

export const SavedMealsApiActions = createActionGroup({
  source: 'Saved Meals | Saved Meals Api',
  events: {
    'Saved Meals Collection Changed': props<{ savedMeals: SavedMeal[] }>(),
    'Unknown Error': props<{ error: unknown }>(),
    'Unsubscribed From Saved Meals Stream': emptyProps(),
  },
});
