import { createSelector } from '@ngrx/store';
import { currentMealFeature } from '../../+state/current-meal.feature';
import { Product } from '../../../products-feature/product.model';

export const selectFilteredProducts = createSelector(
  currentMealFeature.selectNotAddedProducts,
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
