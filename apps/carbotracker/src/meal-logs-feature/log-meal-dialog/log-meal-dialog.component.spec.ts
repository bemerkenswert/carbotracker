import { inferMealTypeFromTime } from './log-meal-dialog.component';

describe('inferMealTypeFromTime', () => {
  it('infers breakfast between 05:00 and 10:59', () => {
    expect(inferMealTypeFromTime(new Date('2026-08-10T05:00'))).toBe(
      'breakfast',
    );
    expect(inferMealTypeFromTime(new Date('2026-08-10T10:59'))).toBe(
      'breakfast',
    );
  });

  it('infers lunch between 11:00 and 16:59', () => {
    expect(inferMealTypeFromTime(new Date('2026-08-10T11:00'))).toBe('lunch');
    expect(inferMealTypeFromTime(new Date('2026-08-10T16:59'))).toBe('lunch');
  });

  it('infers dinner between 17:00 and 21:59', () => {
    expect(inferMealTypeFromTime(new Date('2026-08-10T17:00'))).toBe('dinner');
    expect(inferMealTypeFromTime(new Date('2026-08-10T21:59'))).toBe('dinner');
  });

  it('infers night between 22:00 and 04:59', () => {
    expect(inferMealTypeFromTime(new Date('2026-08-10T22:00'))).toBe('night');
    expect(inferMealTypeFromTime(new Date('2026-08-10T04:59'))).toBe('night');
  });
});
