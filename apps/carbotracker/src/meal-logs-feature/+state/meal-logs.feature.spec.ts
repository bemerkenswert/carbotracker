import { InsulinDose, MealLog, MealLogDocument } from '../meal-log.model';
import {
  HistoryPageComponentActions,
  MealLogsApiActions,
} from './meal-logs.actions';
import { getInitialState, mealLogsFeature } from './meal-logs.feature';

describe('mealLogsFeature', () => {
  const createInsulinDose = (
    id: string,
    createdAt: Date,
    date: string,
  ): InsulinDose => ({
    id,
    type: 'insulin-dose',
    createdAt,
    date,
    insulin: 3,
    note: null,
    creator: 'user-1',
  });

  const createMealLog = (
    id: string,
    createdAt: Date,
    date: string,
  ): MealLog => ({
    id,
    type: 'meal-log',
    createdAt,
    date,
    mealType: 'lunch',
    mealEntries: [],
    insulinToCarbRatio: 1,
    estimatedInsulin: 2,
    actualInsulin: 2.5,
    note: null,
    creator: 'user-1',
  });

  it('stores meal log documents with the entity adapter when the collection changes', () => {
    const dose = createInsulinDose(
      '1',
      new Date('2026-08-10T08:00'),
      '2026-08-10',
    );
    const mealLog = createMealLog(
      '2',
      new Date('2026-08-10T12:00'),
      '2026-08-10',
    );
    const state = mealLogsFeature.reducer(
      getInitialState(),
      MealLogsApiActions.mealLogsCollectionChanged({
        mealLogs: [dose, mealLog],
      }),
    );
    const entityState = mealLogsFeature.selectMealLogs.projector(state);
    const result = mealLogsFeature.selectAll.projector(entityState);
    expect(result).toEqual([dose, mealLog]);
  });

  it('filters meal logs to the selected date', () => {
    const sameDay = createInsulinDose(
      '1',
      new Date('2026-08-10T08:00'),
      '2026-08-10',
    );
    const otherDay = createInsulinDose(
      '2',
      new Date('2026-08-11T08:00'),
      '2026-08-11',
    );
    const all = [sameDay, otherDay];
    const result = mealLogsFeature.selectMealLogsForSelectedDate.projector(
      all,
      '2026-08-10',
    );
    expect(result).toEqual([sameDay]);
  });

  it('sorts meal logs for the selected date chronologically', () => {
    const morning = createInsulinDose(
      '1',
      new Date('2026-08-10T08:00'),
      '2026-08-10',
    );
    const evening = createMealLog(
      '2',
      new Date('2026-08-10T20:00'),
      '2026-08-10',
    );
    const result = mealLogsFeature.selectMealLogsForSelectedDate.projector(
      [evening, morning],
      '2026-08-10',
    );
    expect(result).toEqual([morning, evening]);
  });

  it('exposes the set of dates that have meal log entries', () => {
    const dayOne = createInsulinDose(
      '1',
      new Date('2026-08-10T08:00'),
      '2026-08-10',
    );
    const dayTwo = createInsulinDose(
      '2',
      new Date('2026-08-11T08:00'),
      '2026-08-11',
    );
    const anotherDayTwo = createMealLog(
      '3',
      new Date('2026-08-11T12:00'),
      '2026-08-11',
    );
    const all: MealLogDocument[] = [dayOne, dayTwo, anotherDayTwo];
    const result = mealLogsFeature.selectDatesWithMealLogs.projector(all);
    expect([...result]).toEqual(['2026-08-10', '2026-08-11']);
  });

  it('updates the selected date', () => {
    const state = mealLogsFeature.reducer(
      getInitialState(),
      HistoryPageComponentActions.dateSelected({ date: '2026-08-10' }),
    );
    expect(mealLogsFeature.selectSelectedDate.projector(state)).toBe(
      '2026-08-10',
    );
  });

  it('starts with no selected date', () => {
    expect(
      mealLogsFeature.selectSelectedDate.projector(getInitialState()),
    ).toBeNull();
  });
});
