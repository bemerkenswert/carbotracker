import { createActionGroup, emptyProps, props } from '@ngrx/store';

export const SavedMealsRouterEffectsActions = createActionGroup({
  source: 'Saved Meals | Router Effects',
  events: {
    'Navigation to Saved Meal Page Successful': emptyProps(),
    'Navigation to Saved Meal Page Failed': props<{ error: unknown }>(),
    'Navigation to Saved Meals Page Successful': emptyProps(),
    'Navigation to Saved Meals Page Failed': props<{ error: unknown }>(),
  },
});
