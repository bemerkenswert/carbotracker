import { createSelector } from '@ngrx/store';
import { savedMealsFeature } from '../../+state';
import { SavedMeal } from '../../saved-meal.model';

export interface SavedMealListItem {
  savedMeal: SavedMeal;
  ingredients: string;
  totalCarbs: number;
}

export interface SavedMealsPageViewModel {
  savedMeals: SavedMealListItem[];
  noMatches: boolean;
  nameFilter: string | null;
}

export const selectFilteredSavedMeals = createSelector(
  savedMealsFeature.selectAll,
  savedMealsFeature.selectNameFilter,
  (savedMeals, nameFilter): SavedMeal[] => {
    const trimmedNameFilter = nameFilter?.trim().toLowerCase();
    if (!trimmedNameFilter) {
      return savedMeals;
    }
    return savedMeals.filter((savedMeal) =>
      savedMeal.name.toLowerCase().includes(trimmedNameFilter),
    );
  },
);

export const selectSavedMealsViewModel = createSelector(
  savedMealsFeature.selectAll,
  savedMealsFeature.selectNameFilter,
  selectFilteredSavedMeals,
  (allSavedMeals, nameFilter, filteredSavedMeals): SavedMealsPageViewModel => ({
    savedMeals: filteredSavedMeals.map(toSavedMealListItem),
    noMatches: allSavedMeals.length > 0 && filteredSavedMeals.length === 0,
    nameFilter,
  }),
);

const toSavedMealListItem = (savedMeal: SavedMeal): SavedMealListItem => ({
  savedMeal,
  ingredients: savedMeal.mealEntries
    .map((mealEntry) => mealEntry.name)
    .join(', '),
  totalCarbs: savedMeal.mealEntries.reduce(
    (sum, mealEntry) => sum + mealEntry.amount * (mealEntry.carbs / 100),
    0,
  ),
});
