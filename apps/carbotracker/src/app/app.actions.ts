import { createActionGroup, emptyProps, props } from '@ngrx/store';

export const AppRouterEffectsActions = createActionGroup({
  source: 'App | App Router Effects',
  events: {
    'Navigation to App Successful': emptyProps(),
    'Navigation to App Failed': props<{ error: unknown }>(),
  },
});
