import { Sport } from '../../sport.model';
import { selectEditSportPageViewModel } from './edit-sport-page.selectors';

const createSport = (overrides: Partial<Sport> = {}): Sport => ({
  id: 's1',
  name: 'cycling',
  creator: 'user-a',
  ...overrides,
});

describe('selectEditSportPageViewModel', () => {
  it('provides the current sport as initial form values', () => {
    const sport = createSport({ name: 'cycling' });

    const viewModel = selectEditSportPageViewModel.projector(sport);

    expect(viewModel).toEqual({
      sport,
      pageTitle: 'Edit sport',
      initialFormValues: { name: 'cycling' },
    });
  });

  it('provides null initial form values when there is no selected sport', () => {
    const viewModel = selectEditSportPageViewModel.projector(null);

    expect(viewModel).toEqual({
      sport: null,
      pageTitle: 'Edit sport',
      initialFormValues: null,
    });
  });
});
