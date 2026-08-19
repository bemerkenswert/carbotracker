import { selectCreateProductPageViewModel } from './create-product-page.selectors';

describe('selectCreateProductPageViewModel', () => {
  it('provides the page title and initial form values for a new product', () => {
    const viewModel = selectCreateProductPageViewModel.projector();

    expect(viewModel).toEqual({
      pageTitle: 'Create product',
      initialFormValues: { name: '', carbs: null },
    });
  });
});
