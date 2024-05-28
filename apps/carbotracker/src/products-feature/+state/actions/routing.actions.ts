import { createActionGroup, emptyProps } from '@ngrx/store';

export const ProductsRouterActions = createActionGroup({
  source: 'Products | Router',
  events: {
    'Navigated Away From Products Page': emptyProps(),
  },
});
