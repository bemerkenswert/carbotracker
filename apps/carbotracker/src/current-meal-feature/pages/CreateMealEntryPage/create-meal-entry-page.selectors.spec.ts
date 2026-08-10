import { Product } from '../../../products-feature/product.model';
import { selectCreateMealEntryPageViewModel } from './create-meal-entry-page.selectors';

const createProduct = (id: string, name: string): Product => ({
  id,
  name,
  creator: 'user-a',
  carbs: 50,
});

describe('selectCreateMealEntryPageViewModel', () => {
  it('exposes the filtered products available to add', () => {
    const availableProducts = [
      createProduct('p1', 'spaghetti'),
      createProduct('p2', 'sauce'),
    ];

    const viewModel =
      selectCreateMealEntryPageViewModel.projector(availableProducts);

    expect(viewModel).toEqual({ availableProducts });
  });
});
