import { createActionGroup, emptyProps } from '@ngrx/store';

export const RoutingActions = createActionGroup({
  source: 'Auth | Routing',
  events: {
    'Navigation to Login Page Successful': emptyProps(),
    'Navigation to Login Page Failed': emptyProps(),
    'Navigation to Sign Up Page Successful': emptyProps(),
    'Navigation to Sign Up Page Failed': emptyProps(),
  },
});
