import { Product } from '../product.model';
import { ProductsApiActions } from './actions/api.actions';
import { EditProductPageComponentActions } from './actions/component.actions';
import { getInitialState, productsFeature } from './products.store';

describe('productsFeature', () => {
  const createProduct = (
    id: string,
    name: string,
    creator: string,
  ): Product => ({ id, name, creator, carbs: 25 });

  const spaghetti = createProduct('p1', 'spaghetti', 'user-a');
  const rigatoni = createProduct('p2', 'rigatoni', 'user-b');

  it('returns the initial state for an unknown action', () => {
    const initialState = getInitialState();
    const action = { type: 'Unknown' };

    const state = productsFeature.reducer(initialState, action);

    expect(state).toBe(initialState);
  });

  it('sets the selected product when the selected product changes', () => {
    const state = productsFeature.reducer(
      getInitialState(),
      EditProductPageComponentActions.selectedProductChanged({
        selectedProduct: 'p1',
      }),
    );

    const selectedProduct =
      productsFeature.selectSelectedProduct.projector(state);

    expect(selectedProduct).toBe('p1');
  });

  it('stores the collection of products when the collection changes', () => {
    const state = productsFeature.reducer(
      getInitialState(),
      ProductsApiActions.productsCollectionChanged({
        products: [spaghetti, rigatoni],
      }),
    );

    const selectedProducts = productsFeature.selectProducts.projector(state);
    const products = productsFeature.selectAll.projector(selectedProducts);

    expect(products).toEqual([spaghetti, rigatoni]);
  });

  it('exposes the current product from the selected id', () => {
    let state = productsFeature.reducer(
      getInitialState(),
      ProductsApiActions.productsCollectionChanged({
        products: [spaghetti, rigatoni],
      }),
    );
    state = productsFeature.reducer(
      state,
      EditProductPageComponentActions.selectedProductChanged({
        selectedProduct: 'p1',
      }),
    );
    const selectedProduct =
      productsFeature.selectSelectedProduct.projector(state);
    const products = productsFeature.selectAll.projector(
      productsFeature.selectProducts.projector(state),
    );

    const currentProduct = productsFeature.selectCurrentProduct.projector(
      selectedProduct,
      products,
    );

    expect(currentProduct).toEqual(spaghetti);
  });

  it('exposes null current product when there is no selected product', () => {
    const state = getInitialState();
    const selectedProduct =
      productsFeature.selectSelectedProduct.projector(state);
    const products = productsFeature.selectAll.projector(
      productsFeature.selectProducts.projector(state),
    );

    const currentProduct = productsFeature.selectCurrentProduct.projector(
      selectedProduct,
      products,
    );

    expect(currentProduct).toBeNull();
  });
});
