import { createActionGroup, emptyProps } from '@ngrx/store';

export const ShellComponentActions = createActionGroup({
  source: 'Shell | Shell Component',
  events: {
    'Products Clicked': emptyProps(),
    'Current Meal Clicked': emptyProps(),
    'Saved Meals Clicked': emptyProps(),
    'History Clicked': emptyProps(),
    'Settings Clicked': emptyProps(),
  },
});

export const ShellRouterEffectsActions = createActionGroup({
  source: 'Shell | Shell Router Effects',
  events: {
    'Navigation to Products Page Successful': emptyProps(),
    'Navigation to Products Page Failed': emptyProps(),
    'Navigation to Current Meal Page Successful': emptyProps(),
    'Navigation to Current Meal Page Failed': emptyProps(),
    'Navigation to Saved Meals Page Successful': emptyProps(),
    'Navigation to Saved Meals Page Failed': emptyProps(),
    'Navigation to History Page Successful': emptyProps(),
    'Navigation to History Page Failed': emptyProps(),
    'Navigation to Settings Page Successful': emptyProps(),
    'Navigation to Settings Page Failed': emptyProps(),
  },
});
