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
