import { Product } from '../../product.model';
import { selectEditProductPageViewModel } from './edit-product-page.selectors';

const createProduct = (overrides: Partial<Product> = {}): Product => ({
  id: 'p1',
  name: 'spaghetti',
  creator: 'user-a',
  carbs: 25,
  ...overrides,
});

describe('selectEditProductPageViewModel', () => {
  it('provides the current product as initial form values', () => {
    const product = createProduct({ name: 'spaghetti', carbs: 25 });

    const viewModel = selectEditProductPageViewModel.projector(product);

    expect(viewModel).toEqual({
      product,
      pageTitle: 'Edit product',
      initialFormValues: { name: 'spaghetti', carbs: 25 },
    });
  });

  it('provides null initial form values when there is no selected product', () => {
    const viewModel = selectEditProductPageViewModel.projector(null);

    expect(viewModel).toEqual({
      product: null,
      pageTitle: 'Edit product',
      initialFormValues: null,
    });
  });
});
