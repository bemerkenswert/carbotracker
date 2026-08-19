import { MealEntry } from '../current-meal/current-meal.model';

export interface SavedMeal {
  id: string;
  name: string;
  createdAt: Date;
  mealEntries: MealEntry[];
}
