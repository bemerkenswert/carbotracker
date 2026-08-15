import { createEntityAdapter, EntityState } from '@ngrx/entity';
import {
  createFeature,
  createReducer,
  createSelector,
  MemoizedSelector,
  on,
} from '@ngrx/store';
import { Product } from '../../../features/products/product.model';
import { CurrentMeal, MealEntry } from '../current-meal.model';
import {
  CurrentMealApiActions,
  ProductsApiActions,
} from './actions/api.actions';
import { CreateMealEntryPageComponentActions } from './actions/component.actions';
import { getRouterSelectors } from '@ngrx/router-store';

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

    const selectCurrentMealIsEmpty = createSelector(
      mealEntrySelectors.selectAllMealEntries,
      (mealEntries): boolean => mealEntries.length === 0,
    );
    const selectProductIdFromRoute = createSelector(
      getRouterSelectors().selectRouteParam('id'),
      (id): string | null => id ?? null,
    );
    const selectCurrentMealEntry = createSelector(
      mealEntrySelectors.selectAllMealEntries,
      selectProductIdFromRoute,
      (mealEntries, productId): MealEntry | undefined =>
        mealEntries.find((mealEntry) => mealEntry.productId === productId),
    );

    const selectProductById = createSelector(
      productsSelectors.selectAllProductEntries,
      selectProductIdFromRoute,
      (products, productId): Product | null =>
        products.find((product) => product.id === productId) ?? null,
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
      selectCurrentMealIsEmpty,
      selectCurrentMealEntry,
      selectProductById,
      selectProductIdFromRoute,
      selectNotAddedProducts,
      selectProductsAvailableToAdd,
    };
  },
});
