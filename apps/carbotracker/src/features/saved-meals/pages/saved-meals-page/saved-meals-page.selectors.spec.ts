import { MealEntry } from '../../current-meal/current-meal.model';
import { SavedMeal } from '../../saved-meal.model';
import {
  selectFilteredSavedMeals,
  selectSavedMealsViewModel,
} from './saved-meals-page.selectors';

const createMealEntry = (
  name: string,
  carbs: number,
  amount: number,
): MealEntry => ({ productId: name, name, carbs, amount });

const createSavedMeal = (
  id: string,
  name: string,
  mealEntries: MealEntry[] = [],
): SavedMeal => ({ id, name, createdAt: new Date('2024-01-01'), mealEntries });

describe('selectFilteredSavedMeals', () => {
  const pasta = createSavedMeal('a', 'Creamy pasta');
  const soup = createSavedMeal('b', 'Tomato soup');
  const savedMeals = [pasta, soup];

  it('returns all saved meals when there is no filter', () => {
    const result = selectFilteredSavedMeals.projector(savedMeals, null);

    expect(result).toEqual([pasta, soup]);
  });

  it('returns all saved meals when the filter is blank or whitespace', () => {
    const result = selectFilteredSavedMeals.projector(savedMeals, '   ');

    expect(result).toEqual([pasta, soup]);
  });

  it('filters case-insensitively by a substring of the name', () => {
    const result = selectFilteredSavedMeals.projector(savedMeals, 'PASTA');

    expect(result).toEqual([pasta]);
  });

  it('matches the saved meal name only, not its ingredient names', () => {
    const powerBowl = createSavedMeal('c', 'Power bowl', [
      createMealEntry('tomato', 10, 100),
    ]);

    const result = selectFilteredSavedMeals.projector(
      [powerBowl, soup],
      'tomato',
    );

    expect(result).toEqual([soup]);
  });

  it('returns no saved meals when none match the filter', () => {
    const result = selectFilteredSavedMeals.projector(savedMeals, 'burger');

    expect(result).toEqual([]);
  });
});

describe('selectSavedMealsViewModel', () => {
  const pasta = createSavedMeal('a', 'Creamy pasta');
  const soup = createSavedMeal('b', 'Tomato soup');
  const allSavedMeals = [pasta, soup];

  it('exposes the filtered list and the filter term when some saved meals match', () => {
    const filteredSavedMeals = selectFilteredSavedMeals.projector(
      allSavedMeals,
      'pasta',
    );

    const viewModel = selectSavedMealsViewModel.projector(
      allSavedMeals,
      'pasta',
      filteredSavedMeals,
    );

    expect(viewModel).toEqual({
      savedMeals: [{ savedMeal: pasta, ingredients: '', totalCarbs: 0 }],
      noMatches: false,
      nameFilter: 'pasta',
    });
  });

  it('flags a filter that matches nothing as no matches', () => {
    const filteredSavedMeals = selectFilteredSavedMeals.projector(
      allSavedMeals,
      'burger',
    );

    const viewModel = selectSavedMealsViewModel.projector(
      allSavedMeals,
      'burger',
      filteredSavedMeals,
    );

    expect(viewModel).toEqual({
      savedMeals: [],
      noMatches: true,
      nameFilter: 'burger',
    });
  });

  it('distinguishes having no saved meals at all from no matches', () => {
    const viewModel = selectSavedMealsViewModel.projector([], null, []);

    expect(viewModel).toEqual({
      savedMeals: [],
      noMatches: false,
      nameFilter: null,
    });
  });
});
