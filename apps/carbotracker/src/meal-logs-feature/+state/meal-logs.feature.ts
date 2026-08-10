import { EntityState, createEntityAdapter } from '@ngrx/entity';
import { createFeature, createReducer, createSelector, on } from '@ngrx/store';
import { MealLogDocument } from '../meal-log.model';
import {
  HistoryPageComponentActions,
  MealLogsApiActions,
} from './meal-logs.actions';

interface MealLogsState {
  mealLogs: EntityState<MealLogDocument>;
  selectedDate: string | null;
  error: string | null;
}

const mealLogsEntityAdapter = createEntityAdapter<MealLogDocument>({
  selectId: (mealLog) => mealLog.id,
});

export const getInitialState = (): MealLogsState => ({
  mealLogs: mealLogsEntityAdapter.getInitialState(),
  selectedDate: null,
  error: null,
});

export const mealLogsFeature = createFeature({
  name: 'mealLogs',
  reducer: createReducer(
    getInitialState(),
    on(
      HistoryPageComponentActions.dateSelected,
      (state, { date }): MealLogsState => ({
        ...state,
        selectedDate: date,
      }),
    ),
    on(
      MealLogsApiActions.mealLogsCollectionChanged,
      (state, { mealLogs }): MealLogsState => ({
        ...state,
        mealLogs: mealLogsEntityAdapter.setAll(mealLogs, state.mealLogs),
      }),
    ),
  ),
  extraSelectors: ({ selectMealLogs, selectSelectedDate }) => {
    const entitySelectors = mealLogsEntityAdapter.getSelectors(selectMealLogs);
    const selectMealLogsForSelectedDate = createSelector(
      entitySelectors.selectAll,
      selectSelectedDate,
      (mealLogs, selectedDate): MealLogDocument[] =>
        mealLogs
          .filter((mealLog) => mealLog.date === selectedDate)
          .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime()),
    );
    const selectDatesWithMealLogs = createSelector(
      entitySelectors.selectAll,
      (mealLogs): Set<string> =>
        new Set(mealLogs.map((mealLog) => mealLog.date)),
    );
    return {
      ...entitySelectors,
      selectMealLogsForSelectedDate,
      selectDatesWithMealLogs,
    };
  },
});
