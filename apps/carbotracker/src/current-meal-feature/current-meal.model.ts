export type MealEntry = {
  productId: string;
  name: string;
  carbs: number;
  amount: number;
};

export type CurrentMeal = {
  mealEntries: MealEntry[];
};
