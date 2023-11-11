import { createSelector } from '@ngrx/store';
import { currentMealFeature } from '../../+state/current-meal.feature';
import { Product } from '../../../products-feature/product.model';

export const selectNotAddedProducts = createSelector(
  currentMealFeature.selectAllProductEntries,
  currentMealFeature.selectAllMealEntryIds,
  (products, mealEntryIds): Product[] =>
    products.filter(
      (product) =>
        !mealEntryIds.map((id) => id.toString()).includes(product.id),
    ),
);

export const selectFilteredProducts = createSelector(
  selectNotAddedProducts,
  currentMealFeature.selectProductSearchTerm,
  (products, searchTerm): Product[] => {
    if (searchTerm) {
      return products.filter((product) =>
        product.name.toLowerCase().includes(searchTerm.toLowerCase()),
      );
    } else {
      return products;
    }
  },
);
