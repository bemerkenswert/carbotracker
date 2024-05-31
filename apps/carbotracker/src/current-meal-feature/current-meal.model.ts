export type MealEntry = {
  productId: string;
  name: string;
  carbs: number | null;
  amount: number;
};

export type CurrentMeal = {
  mealEntries: MealEntry[];
};
