import { createActionGroup, emptyProps, props } from '@ngrx/store';

export const ShellRouterEffectsActions = createActionGroup({
  source: 'Shell | Shell Router Effects',
  events: {
    'Navigation to Products Page Successful': emptyProps(),
    'Navigation to Products Page Failed': props<{ error: unknown }>(),
    'Navigation to Current Meal Page Successful': emptyProps(),
    'Navigation to Current Meal Page Failed': props<{ error: unknown }>(),
    'Navigation to Saved Meals Page Successful': emptyProps(),
    'Navigation to Saved Meals Page Failed': props<{ error: unknown }>(),
    'Navigation to Settings Page Successful': emptyProps(),
    'Navigation to Settings Page Failed': props<{ error: unknown }>(),
  },
});
