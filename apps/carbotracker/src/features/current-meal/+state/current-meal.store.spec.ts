import { Product } from '../../../features/products/product.model';
import { MealEntry } from '../current-meal.model';
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

  describe('selectCurrentMealIsEmpty', () => {
    it('is true when there are no meal entries', () => {
      const state = getInitialState();
      const mealEntries = currentMealFeature.selectAllMealEntries.projector(
        currentMealFeature.selectMealEntries.projector(state),
      );
      const result =
        currentMealFeature.selectCurrentMealIsEmpty.projector(mealEntries);
      expect(result).toBe(true);
    });

    it('is false when the current meal has entries', () => {
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
  });

  describe('selectNotAddedProducts', () => {
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
});
