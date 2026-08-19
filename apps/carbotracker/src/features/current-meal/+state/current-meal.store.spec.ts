import { Product } from '../../../features/products/product.model';
import { MealEntry } from '../current-meal.model';
import { CreateMealEntryPageComponentActions } from './actions/component.actions';
import { CurrentMealApiActions } from './actions/api.actions';
import { currentMealFeature, getInitialState } from './current-meal.store';

describe('currentMealFeature', () => {
  const createMealEntry = (productId: string, amount: number): MealEntry => ({
    productId,
    name: productId,
    carbs: 50,
    amount,
  });

  const createProduct = (id: string): Product => ({
    id,
    name: id,
    creator: 'user-a',
    carbs: 50,
  });

  it('returns the initial state for an unknown action', () => {
    const initialState = getInitialState();
    const action = { type: 'Unknown' };

    const state = currentMealFeature.reducer(initialState, action);

    expect(state).toBe(initialState);
  });

  it('stores the product search term when it changes', () => {
    const state = currentMealFeature.reducer(
      getInitialState(),
      CreateMealEntryPageComponentActions.productSearchTermChanged({
        productSearchTerm: 'spaghetti',
      }),
    );

    const productSearchTerm =
      currentMealFeature.selectProductSearchTerm.projector(state);

    expect(productSearchTerm).toBe('spaghetti');
  });

  it('stores the meal entries when the collection changes', () => {
    const state = currentMealFeature.reducer(
      getInitialState(),
      CurrentMealApiActions.currentMealCollectionChanged({
        currentMeal: { mealEntries: [createMealEntry('p1', 100)] },
      }),
    );

    const mealEntries = currentMealFeature.selectAllMealEntries.projector(
      currentMealFeature.selectMealEntries.projector(state),
    );

    expect(mealEntries).toEqual([createMealEntry('p1', 100)]);
  });

  it('is empty when there are no meal entries', () => {
    const state = getInitialState();
    const mealEntries = currentMealFeature.selectAllMealEntries.projector(
      currentMealFeature.selectMealEntries.projector(state),
    );

    const result =
      currentMealFeature.selectCurrentMealIsEmpty.projector(mealEntries);

    expect(result).toBe(true);
  });

  it('is not empty when the current meal has entries', () => {
    const state = currentMealFeature.reducer(
      getInitialState(),
      CurrentMealApiActions.currentMealCollectionChanged({
        currentMeal: { mealEntries: [createMealEntry('p1', 100)] },
      }),
    );
    const mealEntries = currentMealFeature.selectAllMealEntries.projector(
      currentMealFeature.selectMealEntries.projector(state),
    );

    const result =
      currentMealFeature.selectCurrentMealIsEmpty.projector(mealEntries);

    expect(result).toBe(false);
  });

  it('excludes products that already have an entry in the current meal', () => {
    const mealEntryIds = currentMealFeature.selectAllMealEntryIds.projector(
      currentMealFeature.selectMealEntries.projector(
        currentMealFeature.reducer(
          getInitialState(),
          CurrentMealApiActions.currentMealCollectionChanged({
            currentMeal: { mealEntries: [createMealEntry('p1', 100)] },
          }),
        ),
      ),
    );

    const result = currentMealFeature.selectNotAddedProducts.projector(
      [createProduct('p1'), createProduct('p2')],
      mealEntryIds,
    );

    expect(result).toEqual([createProduct('p2')]);
  });
});
