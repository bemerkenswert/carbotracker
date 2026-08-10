import { SettingsState } from '../../../app/app.reducer';
import { selectInsulinUnits } from './current-meal-page.selectors';

describe('selectInsulinUnits', () => {
  const createSettingsState = (
    insulinToCarbRatios: SettingsState['insulinToCarbRatios'],
  ): SettingsState => ({ insulinToCarbRatios });

  it('computes night insulin units from the night ratio', () => {
    const state = createSettingsState({
      showInsulinUnits: true,
      breakfast: 1,
      lunch: 2,
      dinner: 3,
      night: 4,
    });

    const result = selectInsulinUnits.projector(state, 100);

    expect(result.night).toBe(40);
  });

  it('returns 0 night insulin units when the night ratio is not set', () => {
    const state = createSettingsState({
      showInsulinUnits: true,
      breakfast: 1,
      lunch: 2,
      dinner: 3,
      night: null,
    });

    const result = selectInsulinUnits.projector(state, 100);

    expect(result.night).toBe(0);
  });
});
