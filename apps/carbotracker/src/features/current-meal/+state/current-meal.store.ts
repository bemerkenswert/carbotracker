import { createEntityAdapter, EntityState } from '@ngrx/entity';
import {
  createFeature,
  createReducer,
  createSelector,
  MemoizedSelector,
  on,
} from '@ngrx/store';
import { getRouterSelectors } from '@ngrx/router-store';
import { productsFeature } from '../../products/+state';
import { Product } from '../../products/product.model';
import { CurrentMeal, MealEntry } from '../current-meal.model';
import { CurrentMealApiActions } from './actions/api.actions';
import { CreateMealEntryPageComponentActions } from './actions/component.actions';

interface CurrentMealState {
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

export const getInitialState = (): CurrentMealState => ({
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
      productsFeature.selectAll,
      selectProductIdFromRoute,
      (products, productId): Product | null =>
        products.find((product) => product.id === productId) ?? null,
    );

    const selectNotAddedProducts = createSelector(
      productsFeature.selectAll,
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
