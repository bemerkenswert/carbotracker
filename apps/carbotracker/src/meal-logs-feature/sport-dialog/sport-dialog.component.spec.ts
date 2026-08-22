import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { MAT_DIALOG_DATA } from '@angular/material/dialog';
import { By } from '@angular/platform-browser';
import { SportDialogComponent } from './sport-dialog.component';

describe('SportDialogComponent', () => {
  let fixture: ComponentFixture<SportDialogComponent>;
  let component: SportDialogComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SportDialogComponent, NoopAnimationsModule],
      providers: [{ provide: MAT_DIALOG_DATA, useValue: {} }],
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
});
