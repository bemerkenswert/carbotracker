import { EntityState, createEntityAdapter } from '@ngrx/entity';
import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { Product } from '../product.model';
import {
  EditProductPageComponentActions,
  ProductsApiActions,
} from './products.actions';

interface ProductsState {
  products: EntityState<Product>;
  selectedProduct: string | null;
}

const productsEntityAdapter = createEntityAdapter<Product>();

export const getInitialState = (): ProductsState => ({
  products: productsEntityAdapter.getInitialState(),
  selectedProduct: null,
});

export const productsFeature = createFeature({
  name: 'products',
  reducer: createReducer(
    getInitialState(),
    on(
      EditProductPageComponentActions.selectedProductChanged,
      (state, { selectedProduct }): ProductsState => ({
        ...state,
        selectedProduct,
      })
    ),
    on(
      ProductsApiActions.productsCollectionChanged,
      (state, { products }): ProductsState => ({
        ...state,
        products: productsEntityAdapter.setAll(products, state.products),
      })
    )
  ),
  extraSelectors: ({ selectProducts, selectSelectedProduct }) => {
    const entitySelectors = productsEntityAdapter.getSelectors(selectProducts);
    const selectCurrentProduct = createSelector(
      selectSelectedProduct,
      entitySelectors.selectAll,
      (productId, products): Product | null =>
        products.find((product) => product.id === productId) ?? null
    );
    return {
      ...entitySelectors,
      selectCurrentProduct,
    };
  },
});
