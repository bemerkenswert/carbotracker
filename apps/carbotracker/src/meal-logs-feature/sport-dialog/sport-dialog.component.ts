import { Component, inject } from '@angular/core';
import {
  AbstractControl,
  FormBuilder,
  FormControl,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatNativeDateModule } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatDialogModule, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatRadioModule } from '@angular/material/radio';
import { toLocalTimeString } from '../date.util';
import {
  BasalReductionMode,
  SportDialogData,
  SportDialogResult,
} from './sport-dialog.model';

const greaterThanZero = (
  control: AbstractControl<number | null>,
): ValidationErrors | null => {
  const value = control.value;
  if (value === null || value === undefined || value <= 0) {
    return { greaterThanZero: true };
  }
  return null;
};

const createSportFormGroup = (data: SportDialogData) => {
  const fb = inject(FormBuilder);
  return fb.group({
    date: new FormControl<Date>(data.defaultDate ?? new Date(), {
      nonNullable: true,
      validators: [Validators.required],
    }),
    time: new FormControl<string>(toLocalTimeString(new Date()), {
      nonNullable: true,
      validators: [Validators.required],
    }),
    duration: new FormControl<number | null>(null, {
      validators: [Validators.required, greaterThanZero],
    }),
    sportName: new FormControl<string>('', {
      nonNullable: true,
      validators: [Validators.required],
    }),
    reductionMode: new FormControl<BasalReductionMode>('none', {
      nonNullable: true,
    }),
    basalRate: new FormControl<number | null>(null),
    basalReductionPercent: new FormControl<number | null>(null),
    note: new FormControl<string>('', { nonNullable: true }),
  });
};

@Component({
  selector: 'carbotracker-sport-dialog',
  imports: [
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatDatepickerModule,
    MatNativeDateModule,
    MatRadioModule,
    ReactiveFormsModule,
  ],
  templateUrl: './sport-dialog.component.html',
  styleUrls: ['./sport-dialog.component.scss'],
})
export class SportDialogComponent {
  private readonly data = inject<SportDialogData>(MAT_DIALOG_DATA);

  protected readonly sportForm = createSportFormGroup(this.data);

  protected get canSave(): boolean {
    return this.sportForm.valid;
  }

  protected onReductionModeChange(mode: BasalReductionMode) {
    const rateControl = this.sportForm.controls.basalRate;
    const percentControl = this.sportForm.controls.basalReductionPercent;
    if (mode === 'rate') {
      rateControl.setValidators([Validators.required, greaterThanZero]);
      percentControl.clearValidators();
    } else if (mode === 'percent') {
      percentControl.setValidators([Validators.required, greaterThanZero]);
      rateControl.clearValidators();
    } else {
      rateControl.clearValidators();
      percentControl.clearValidators();
    }
    rateControl.updateValueAndValidity();
    percentControl.updateValueAndValidity();
  }

  protected getResult(): SportDialogResult {
    const formValue = this.sportForm.getRawValue();
    const [hours, minutes] = formValue.time.split(':').map(Number);
    const date = new Date(formValue.date);
    date.setHours(hours, minutes, 0, 0);
    return {
      cancelled: false,
      date,
      duration: formValue.duration as number,
      sportName: formValue.sportName.trim(),
      basalRate:
        formValue.reductionMode === 'rate' ? formValue.basalRate : null,
      basalReductionPercent:
        formValue.reductionMode === 'percent'
          ? formValue.basalReductionPercent
          : null,
      note: formValue.note.trim() || null,
    };
  }
}
