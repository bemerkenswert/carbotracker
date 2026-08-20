import { MealEntry } from '../../features/current-meal/current-meal.model';
import { MealType } from '../meal-log.model';

export interface LogMealDialogData {
  mealEntries: MealEntry[];
  showInsulinUnits: boolean;
  insulinToCarbRatios: {
    breakfast: number | null;
    lunch: number | null;
    dinner: number | null;
    night: number | null;
  };
}

export type ConfirmedLogMealDialogResult = {
  cancelled: false;
  date: Date;
  mealType: MealType;
  estimatedInsulin: number;
  actualInsulin: number;
  note: string | null;
};

export type LogMealDialogResult =
  | { cancelled: true }
  | ConfirmedLogMealDialogResult;
