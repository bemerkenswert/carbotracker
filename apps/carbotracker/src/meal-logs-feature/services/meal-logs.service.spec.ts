import { SportLog } from '../meal-log.model';
import { transformMealLogDocument } from './meal-logs.service';

describe('transformMealLogDocument', () => {
  it('maps a sport-log document into a SportLog with a rate reduction', () => {
    const createdAt = new Date('2026-08-10T23:30');
    const document = {
      type: 'sport-log',
      createdAt: { toDate: () => createdAt },
      date: '2026-08-10',
      duration: 2.5,
      sportName: 'Cycling',
      basalRate: 0.5,
      basalReductionPercent: null,
      note: 'fast pace',
      creator: 'user-1',
    };

    const result = transformMealLogDocument('s1', document);

    const expected: SportLog = {
      id: 's1',
      type: 'sport-log',
      createdAt,
      date: '2026-08-10',
      duration: 2.5,
      sportName: 'Cycling',
      basalRate: 0.5,
      basalReductionPercent: null,
      note: 'fast pace',
      creator: 'user-1',
    };
    expect(result).toEqual(expected);
  });

  it('maps a sport-log document with a percentage reduction', () => {
    const createdAt = new Date('2026-08-11T14:00');
    const document = {
      type: 'sport-log',
      createdAt: { toDate: () => createdAt },
      date: '2026-08-11',
      duration: 1,
      sportName: 'Swimming',
      basalRate: null,
      basalReductionPercent: 30,
      note: null,
      creator: 'user-1',
    };

    const result = transformMealLogDocument('s2', document);

    expect(result).toMatchObject({
      type: 'sport-log',
      duration: 1,
      sportName: 'Swimming',
      basalRate: null,
      basalReductionPercent: 30,
      note: null,
    });
  });

  it('defaults missing fields on a sport-log document without a reduction', () => {
    const createdAt = new Date('2026-08-11T14:00');
    const document = {
      type: 'sport-log',
      createdAt: { toDate: () => createdAt },
      date: '2026-08-11',
      creator: 'user-1',
    };

    const result = transformMealLogDocument('s3', document);

    expect(result).toMatchObject({
      type: 'sport-log',
      createdAt,
      date: '2026-08-11',
      duration: 0,
      sportName: '',
      basalRate: null,
      basalReductionPercent: null,
      note: null,
      creator: 'user-1',
    });
  });
});
