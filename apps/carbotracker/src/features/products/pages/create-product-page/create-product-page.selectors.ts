import { createSelector } from '@ngrx/store';

export interface CreateProductPageViewModel {
  pageTitle: string;
  initialFormValues: { name: string; carbs: number | null };
}

export const selectCreateProductPageViewModel = createSelector(
  (): CreateProductPageViewModel => ({
    pageTitle: 'Create product',
    initialFormValues: { name: '', carbs: null },
  }),
);
