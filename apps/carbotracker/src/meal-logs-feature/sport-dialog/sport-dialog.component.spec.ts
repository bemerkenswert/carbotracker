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

describe('SportDialogComponent in edit mode', () => {
  let fixture: ComponentFixture<SportDialogComponent>;
  let component: SportDialogComponent;

  const editData = {
    sportLog: {
      createdAt: new Date('2026-08-10T14:30'),
      duration: 2.5,
      sportName: 'Cycling',
      basalRate: 0.5,
      basalReductionPercent: null,
      note: 'fast pace',
    },
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SportDialogComponent, NoopAnimationsModule],
      providers: [
        { provide: MAT_DIALOG_DATA, useValue: editData },
        provideMockStore({ initialState: { sports: getSportsInitialState() } }),
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(SportDialogComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('pre-fills all fields from the sport log being edited', () => {
    expect(component.isEditing).toBe(true);
    expect(component.sportForm.controls.date.value).toEqual(
      new Date('2026-08-10T14:30'),
    );
    expect(component.sportForm.controls.time.value).toBe('14:30');
    expect(component.sportForm.controls.duration.value).toBe(2.5);
    expect(component.sportForm.controls.sportName.value).toBe('Cycling');
    expect(component.sportForm.controls.note.value).toBe('fast pace');
  });

  it('pre-fills the rate reduction mode and value', () => {
    expect(component.sportForm.controls.reductionMode.value).toBe('rate');
    expect(component.sportForm.controls.basalRate.value).toBe(0.5);
  });

  it('disables save-to-catalog in edit mode', () => {
    expect(component.sportForm.controls.saveToCatalog.disabled).toBe(true);
  });

  it('keeps a free-text sport name without a matching catalog sport as-is', () => {
    expect(component.sportForm.controls.catalogSportId.value).toBeNull();
    expect(component.sportForm.controls.sportName.value).toBe('Cycling');
  });
});

describe('SportDialogComponent in edit mode with a percentage reduction', () => {
  let component: SportDialogComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SportDialogComponent, NoopAnimationsModule],
      providers: [
        {
          provide: MAT_DIALOG_DATA,
          useValue: {
            sportLog: {
              createdAt: new Date('2026-08-10T14:30'),
              duration: 1,
              sportName: 'Running',
              basalRate: null,
              basalReductionPercent: 30,
              note: null,
            },
          },
        },
        provideMockStore({ initialState: { sports: getSportsInitialState() } }),
      ],
    }).compileComponents();

    const fixture = TestBed.createComponent(SportDialogComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('pre-fills the percentage reduction mode and value', () => {
    expect(component.sportForm.controls.reductionMode.value).toBe('percent');
    expect(component.sportForm.controls.basalReductionPercent.value).toBe(30);
  });
});
