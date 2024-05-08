import { EntityState, createEntityAdapter } from '@ngrx/entity';
import {
  MemoizedSelector,
  createFeature,
  createReducer,
  createSelector,
  on,
} from '@ngrx/store';
import { Product } from '../../products-feature/product.model';
import { CurrentMeal, MealEntry } from '../current-meal.model';
import {
  CreateMealEntryPageComponentActions,
  CurrentMealApiActions,
  ProductsApiActions,
} from './current-meal.actions';

interface CurrentMealState {
  products: EntityState<Product>;
  mealEntries: EntityState<MealEntry>;
  productSearchTerm: string | null;
  error: string | null;
}

const mealEntriesEntityAdapter = createEntityAdapter<MealEntry>({
  selectId: (mealEntry) => mealEntry.productId,
});
const getMealEntriesSelectors = (
  selectState: MemoizedSelector<
    Record<string, unknown>,
    EntityState<MealEntry>
  >,
) => {
  const { selectAll, selectIds } =
    mealEntriesEntityAdapter.getSelectors(selectState);
  return { selectAllMealEntries: selectAll, selectAllMealEntryIds: selectIds };
};

const productsEntriesEntityAdapter = createEntityAdapter<Product>();
const getProductsEntriesSelectors = (
  selectState: MemoizedSelector<Record<string, unknown>, EntityState<Product>>,
) => {
  const { selectAll, selectIds } =
    productsEntriesEntityAdapter.getSelectors(selectState);
  return {
    selectAllProductEntries: selectAll,
    selectAllProductEntryIds: selectIds,
  };
};

export const getInitialState = (): CurrentMealState => ({
  products: productsEntriesEntityAdapter.getInitialState(),
  mealEntries: mealEntriesEntityAdapter.getInitialState(),
  productSearchTerm: null,
  error: null,
});

export const currentMealFeature = createFeature({
  name: 'currentMeal',
  reducer: createReducer(
    getInitialState(),
    on(
      CreateMealEntryPageComponentActions.productSearchTermChanged,
      (state, { productSearchTerm }): CurrentMealState => ({
        ...state,
        productSearchTerm,
      }),
    ),
    on(
      ProductsApiActions.productsCollectionChanged,
      (state, { products }): CurrentMealState => ({
        ...state,
        products: productsEntriesEntityAdapter.setAll(products, state.products),
      }),
    ),
    on(
      CurrentMealApiActions.currentMealCollectionChanged,
      (state, { currentMeal }): CurrentMealState => {
        return {
          ...state,
          mealEntries: mealEntriesEntityAdapter.setAll(
            currentMeal.mealEntries,
            state.mealEntries,
          ),
        };
      },
    ),
  ),
  extraSelectors(baseSelectors) {
    const mealEntrySelectors = getMealEntriesSelectors(
      baseSelectors.selectMealEntries,
    );
    const productsSelectors = getProductsEntriesSelectors(
      baseSelectors.selectProducts,
    );

    const selectCurrentMeal = createSelector(
      mealEntrySelectors.selectAllMealEntries,
      (mealEntries): CurrentMeal => ({ mealEntries }),
    );
    const selectNotAddedProducts = createSelector(
      productsSelectors.selectAllProductEntries,
      mealEntrySelectors.selectAllMealEntryIds,
      (products, mealEntryIds): Product[] =>
        products.filter(
          (product) =>
            !mealEntryIds.map((id) => id.toString()).includes(product.id),
        ),
    );

    const selectProductsAvailableToAdd = createSelector(
      selectNotAddedProducts,
      (products): boolean => products.length > 0,
    );

    return {
      ...mealEntrySelectors,
      ...productsSelectors,
      selectCurrentMeal,
      selectNotAddedProducts,
      selectProductsAvailableToAdd,
    };
  },
});
