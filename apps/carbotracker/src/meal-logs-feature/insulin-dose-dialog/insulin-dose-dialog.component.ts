import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatNativeDateModule } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatDialogModule } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { toLocalTimeString } from '../date.util';
import { InsulinDoseDialogResult } from './insulin-dose-dialog.model';

@Component({
  selector: 'carbotracker-insulin-dose-dialog',
  imports: [
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatDatepickerModule,
    MatNativeDateModule,
    FormsModule,
  ],
  templateUrl: './insulin-dose-dialog.component.html',
  styleUrls: ['./insulin-dose-dialog.component.scss'],
})
export class InsulinDoseDialogComponent {
  protected date: Date = new Date();
  protected time: string = toLocalTimeString(new Date());
  protected insulin: number | null = null;
  protected note = '';

  protected get canSave(): boolean {
    return (
      this.insulin !== null &&
      this.insulin > 0 &&
      !Number.isNaN(this.selectedDateTime().getTime())
    );
  }

  protected getResult(): InsulinDoseDialogResult {
    return {
      cancelled: false,
      date: this.selectedDateTime(),
      insulin: this.insulin as number,
      note: this.note.trim() || null,
    };
  }

  private selectedDateTime(): Date {
    const [hours, minutes] = this.time.split(':').map(Number);
    const date = new Date(this.date);
    date.setHours(hours, minutes, 0, 0);
    return date;
  }
}
