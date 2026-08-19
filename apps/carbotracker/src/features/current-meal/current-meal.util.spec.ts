import { estimateInsulin, sumOfMealEntryCarbs } from './current-meal.util';
import { MealEntry } from './current-meal.model';

describe('sumOfMealEntryCarbs', () => {
  it('sums the density-weighted carb mass across entries', () => {
    const mealEntries: MealEntry[] = [
      { productId: 'p1', name: 'spaghetti', carbs: 25, amount: 200 },
      { productId: 'p2', name: 'bread', carbs: 50, amount: 100 },
    ];

    const result = sumOfMealEntryCarbs(mealEntries);

    expect(result).toBe(100);
  });

  it('returns 0 for an empty meal', () => {
    expect(sumOfMealEntryCarbs([])).toBe(0);
  });
});

describe('estimateInsulin', () => {
  it('computes insulin units from carbs and the insulin-to-carb ratio', () => {
    expect(estimateInsulin(100, 4)).toBe(40);
  });
});
