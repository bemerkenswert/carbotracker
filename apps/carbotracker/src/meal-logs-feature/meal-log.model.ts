import { MealEntry } from '../features/current-meal/current-meal.model';

export type MealType = 'breakfast' | 'lunch' | 'dinner' | 'night';

export type MealLogDocumentType = 'meal-log' | 'insulin-dose' | 'sport-log';

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

export interface SportLog {
  id: string;
  type: 'sport-log';
  /** The session's start date+time in local time. */
  createdAt: Date;
  /** Normalized `YYYY-MM-DD` day-key of the start day in local time, so a
   *  session crossing midnight still appears on the day it started. */
  date: string;
  /** Duration in hours, decimals allowed (e.g. `2.5`). */
  duration: number;
  /** Snapshot of the sport's name at logging time (catalog or free-text). */
  sportName: string;
  /** Temporary basal rate in U/h. Exactly one of `basalRate` and
   *  `basalReductionPercent` is set when a reduction is present; both are
   *  `null` when there is none. */
  basalRate: number | null;
  /** Basal reduction as a percentage of the basal rate (e.g. `30` means
   *  −30%). */
  basalReductionPercent: number | null;
  note: string | null;
  creator: string;
}

export type MealLogDocument = MealLog | InsulinDose | SportLog;
