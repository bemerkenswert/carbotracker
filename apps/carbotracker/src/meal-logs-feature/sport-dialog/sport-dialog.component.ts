import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
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
    FormsModule,
  ],
  templateUrl: './sport-dialog.component.html',
  styleUrls: ['./sport-dialog.component.scss'],
})
export class SportDialogComponent {
  private readonly data = inject<SportDialogData>(MAT_DIALOG_DATA);

  protected date: Date = this.data.defaultDate ?? new Date();
  protected time: string = toLocalTimeString(new Date());
  protected duration: number | null = null;
  protected sportName = '';
  protected reductionMode: BasalReductionMode = 'none';
  protected basalRate: number | null = null;
  protected basalReductionPercent: number | null = null;
  protected note = '';

  protected get canSave(): boolean {
    return (
      this.sportName.trim().length > 0 &&
      this.duration !== null &&
      this.duration > 0 &&
      this.isReductionValid() &&
      !Number.isNaN(this.selectedDateTime().getTime())
    );
  }

  protected get validationMessage(): string | null {
    if (this.sportName.trim().length === 0) {
      return 'Enter a sport name.';
    }
    if (this.duration === null || this.duration <= 0) {
      return 'Enter a duration greater than 0.';
    }
    if (
      this.reductionMode === 'rate' &&
      (this.basalRate === null || this.basalRate <= 0)
    ) {
      return 'Enter a basal rate greater than 0.';
    }
    if (
      this.reductionMode === 'percent' &&
      (this.basalReductionPercent === null || this.basalReductionPercent <= 0)
    ) {
      return 'Enter a reduction percentage greater than 0.';
    }
    if (Number.isNaN(this.selectedDateTime().getTime())) {
      return 'Enter a valid date and time.';
    }
    return null;
  }

  protected getResult(): SportDialogResult {
    return {
      cancelled: false,
      date: this.selectedDateTime(),
      duration: this.duration as number,
      sportName: this.sportName.trim(),
      basalRate: this.reductionMode === 'rate' ? this.basalRate : null,
      basalReductionPercent:
        this.reductionMode === 'percent' ? this.basalReductionPercent : null,
      note: this.note.trim() || null,
    };
  }

  private isReductionValid(): boolean {
    if (this.reductionMode === 'rate') {
      return this.basalRate !== null && this.basalRate > 0;
    }
    if (this.reductionMode === 'percent') {
      return (
        this.basalReductionPercent !== null && this.basalReductionPercent > 0
      );
    }
    return true;
  }

  private selectedDateTime(): Date {
    const [hours, minutes] = this.time.split(':').map(Number);
    const date = new Date(this.date);
    date.setHours(hours, minutes, 0, 0);
    return date;
  }
}
