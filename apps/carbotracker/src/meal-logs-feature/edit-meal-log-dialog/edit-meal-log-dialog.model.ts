import { MealType } from '../meal-log.model';

export interface EditMealLogDialogData {
  mealLog: {
    createdAt: Date;
    mealType: MealType;
    estimatedInsulin: number;
    actualInsulin: number;
    note: string | null;
  };
}

export type ConfirmedEditMealLogDialogResult = {
  cancelled: false;
  date: Date;
  mealType: MealType;
  actualInsulin: number;
  note: string | null;
};

export type EditMealLogDialogResult =
  | { cancelled: true }
  | ConfirmedEditMealLogDialogResult;
