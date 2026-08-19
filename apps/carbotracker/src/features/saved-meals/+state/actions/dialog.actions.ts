import { createActionGroup, emptyProps, props } from '@ngrx/store';
import { SavedMeal } from '../../saved-meal.model';

export const DeleteSavedMealConfirmationDialogActions = createActionGroup({
  source: 'Saved Meals | Delete Saved Meal Confirmation Dialog',
  events: {
    'Confirm Clicked': props<{ savedMeal: SavedMeal }>(),
    'Abort Clicked': emptyProps(),
  },
});
