import { createSelector } from '@ngrx/store';
import { mealLogsFeature } from '../../+state/meal-logs.feature';

export const selectHistoryPageViewModel = createSelector(
  mealLogsFeature.selectMealLogsForSelectedDate,
  mealLogsFeature.selectDatesWithMealLogs,
  mealLogsFeature.selectSelectedDate,
  (mealLogsForSelectedDate, datesWithMealLogs, selectedDate) => ({
    mealLogsForSelectedDate,
    datesWithMealLogs,
    selectedDate,
  }),
);
