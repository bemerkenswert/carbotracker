import { Sport } from '../../sport.model';
import {
  selectCreateSportPageViewModel,
  selectSportNameAlreadyExists,
} from './create-sport-page.selectors';

const createSport = (overrides: Partial<Sport> = {}): Sport => ({
  id: 's1',
  name: 'cycling',
  creator: 'user-a',
  ...overrides,
});

describe('selectCreateSportPageViewModel', () => {
  it('provides the page title and initial form values for a new sport', () => {
    const viewModel = selectCreateSportPageViewModel.projector();

    expect(viewModel).toEqual({
      pageTitle: 'Create sport',
      initialFormValues: { name: '' },
    });
  });
});

describe('selectSportNameAlreadyExists', () => {
  it('flags a name that already exists in the catalog ignoring case', () => {
    const sports = [
      createSport({ name: 'Cycling' }),
      createSport({ id: 's2', name: 'running' }),
    ];
    const isNameTaken = selectSportNameAlreadyExists.projector(sports);

    expect(isNameTaken('cycling')).toBe(true);
    expect(isNameTaken('CYCLING')).toBe(true);
  });

  it('does not flag a name that is not in the catalog', () => {
    const sports = [createSport({ name: 'cycling' })];
    const isNameTaken = selectSportNameAlreadyExists.projector(sports);

    expect(isNameTaken('swimming')).toBe(false);
  });

  it('does not flag an empty catalog', () => {
    const isNameTaken = selectSportNameAlreadyExists.projector([]);

    expect(isNameTaken('cycling')).toBe(false);
  });
});
