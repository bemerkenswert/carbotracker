import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { MAT_DIALOG_DATA } from '@angular/material/dialog';
import { provideMockStore } from '@ngrx/store/testing';
import { Store } from '@ngrx/store';
import { By } from '@angular/platform-browser';
import { getInitialState as getSportsInitialState } from '../../features/sports/+state/sports.store';
import { Sport } from '../../features/sports/sport.model';
import { SportDialogComponent } from './sport-dialog.component';

describe('SportDialogComponent', () => {
  let fixture: ComponentFixture<SportDialogComponent>;
  let component: SportDialogComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SportDialogComponent, NoopAnimationsModule],
      providers: [
        { provide: MAT_DIALOG_DATA, useValue: {} },
        provideMockStore({ initialState: { sports: getSportsInitialState() } }),
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(SportDialogComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  const saveButton = (): HTMLButtonElement => {
    const saveButton = fixture.debugElement
      .queryAll(By.css('button'))
      .find((button) => button.nativeElement.textContent?.includes('Save'));
    if (!saveButton) {
      throw new Error('Save button not found');
    }
    return saveButton.nativeElement;
  };

  it('enables Save once a sport name and a duration greater than 0 are set', () => {
    component.sportForm.controls.duration.setValue(2.5);
    component.sportForm.controls.sportName.setValue('Cycling');
    fixture.detectChanges();

    expect(component.sportForm.valid).toBe(true);
    expect(saveButton().disabled).toBe(false);
  });

  it('keeps Save disabled while the sport name is missing', () => {
    component.sportForm.controls.duration.setValue(2.5);
    fixture.detectChanges();

    expect(component.sportForm.valid).toBe(false);
    expect(saveButton().disabled).toBe(true);
  });

  it('keeps Save disabled while the duration is missing or zero', () => {
    component.sportForm.controls.sportName.setValue('Cycling');
    fixture.detectChanges();

    expect(component.sportForm.valid).toBe(false);
    expect(saveButton().disabled).toBe(true);

    component.sportForm.controls.duration.setValue(0);
    fixture.detectChanges();

    expect(saveButton().disabled).toBe(true);
  });

  const seedCatalog = (sports: Sport[]) => {
    const store = TestBed.inject(Store);
    store.setState({
      sports: {
        ...getSportsInitialState(),
        sports: {
          ids: sports.map((sport) => sport.id),
          entities: Object.fromEntries(
            sports.map((sport) => [sport.id, sport]),
          ),
        },
      },
    });
    fixture.detectChanges();
  };

  it('lists catalog sports in the autocomplete while typing', () => {
    seedCatalog([
      { id: 's1', name: 'Cycling', creator: 'user-a' },
      { id: 's2', name: 'Running', creator: 'user-a' },
    ]);
    component.sportForm.controls.sportName.setValue('Cyc');

    expect(component.filteredCatalogSports()).toEqual([
      { id: 's1', name: 'Cycling', creator: 'user-a' },
    ]);
  });

  it('marks a picked catalog sport as selected and disables save-to-catalog', () => {
    seedCatalog([
      { id: 's1', name: 'Cycling', creator: 'user-a' },
      { id: 's2', name: 'Running', creator: 'user-a' },
    ]);
    component.sportForm.controls.sportName.setValue('Cycling');
    component.onCatalogSportSelected('Cycling');

    expect(component.sportForm.controls.catalogSportId.value).toBe('s1');
    expect(component.sportForm.controls.saveToCatalog.value).toBe(false);
  });

  it('keeps a free-typed value that matches no catalog sport as free text', () => {
    seedCatalog([
      { id: 's1', name: 'Cycling', creator: 'user-a' },
      { id: 's2', name: 'Running', creator: 'user-a' },
    ]);
    component.sportForm.controls.sportName.setValue('CrossFit');
    component.onSportNameTyped();

    expect(component.sportForm.controls.catalogSportId.value).toBeNull();
    expect(component.sportForm.controls.saveToCatalog.disabled).toBe(false);
  });

  it('clears the selected catalog sport when the name is typed over', () => {
    seedCatalog([
      { id: 's1', name: 'Cycling', creator: 'user-a' },
      { id: 's2', name: 'Running', creator: 'user-a' },
    ]);
    component.sportForm.controls.sportName.setValue('Cycling');
    component.onCatalogSportSelected('Cycling');
    component.sportForm.controls.sportName.setValue('Cycling long');
    component.onSportNameTyped();

    expect(component.sportForm.controls.catalogSportId.value).toBeNull();
  });
});
