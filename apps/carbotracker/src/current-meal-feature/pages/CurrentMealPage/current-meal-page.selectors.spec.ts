import { selectInsulinUnits } from './current-meal-page.selectors';
import { ThemePreference } from '../../../features/settings/theme-preference.model';

interface InsulinToCarbRatios {
  showInsulinUnits: boolean;
  breakfast: number | null;
  lunch: number | null;
  dinner: number | null;
  night: number | null;
}

interface SettingsState {
  insulinToCarbRatios: InsulinToCarbRatios;
  themePreference: ThemePreference;
}

describe('selectInsulinUnits', () => {
  const createSettingsState = (
    insulinToCarbRatios: InsulinToCarbRatios,
  ): SettingsState => ({ insulinToCarbRatios, themePreference: 'system' });

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
