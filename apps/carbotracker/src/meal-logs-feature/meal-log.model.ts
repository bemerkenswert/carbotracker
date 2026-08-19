import { MealEntry } from '../current-meal-feature/current-meal.model';

export type MealType = 'breakfast' | 'lunch' | 'dinner' | 'night';

export type MealLogDocumentType = 'meal-log' | 'insulin-dose';

export interface MealLog {
  id: string;
  type: 'meal-log';
  createdAt: Date;
  /** Normalized `YYYY-MM-DD` day-key in local time. Stored as a string so
   *  calendar filtering (`mealLog.date === selectedDate`) and tile
   *  highlighting compare plain strings without timezone drift. */
  date: string;
  mealType: MealType;
  mealEntries: MealEntry[];
  insulinToCarbRatio: number;
  estimatedInsulin: number;
  actualInsulin: number;
  note: string | null;
  creator: string;
}

export interface InsulinDose {
  id: string;
  type: 'insulin-dose';
  createdAt: Date;
  /** Normalized `YYYY-MM-DD` day-key in local time. Stored as a string so
   *  calendar filtering and tile highlighting compare plain strings
   *  without timezone drift. */
  date: string;
  insulin: number;
  note: string | null;
  creator: string;
}

export type MealLogDocument = MealLog | InsulinDose;
