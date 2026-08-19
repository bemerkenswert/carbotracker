import { createActionGroup, emptyProps, props } from '@ngrx/store';

export const CurrentMealRouterEffectsActions = createActionGroup({
  source: 'Current Meal | Router Effects',
  events: {
    'Navigation to Create Meal Entry Page Successful': emptyProps(),
    'Navigation to Create Meal Entry Page Failed': props<{
      error: unknown;
    }>(),
    'Navigation to Current Meal Page Successful': emptyProps(),
    'Navigation to Current Meal Page Failed': props<{ error: unknown }>(),
    'Navigation to Edit Meal Entry Page Successful': emptyProps(),
    'Navigation to Edit Meal Entry Page Failed': props<{
      error: unknown;
    }>(),
  },
});
