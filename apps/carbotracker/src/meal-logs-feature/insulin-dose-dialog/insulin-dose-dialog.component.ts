import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { toLocalDateTimeString } from '../date.util';
import { InsulinDoseDialogResult } from './insulin-dose-dialog.model';

@Component({
  selector: 'carbotracker-insulin-dose-dialog',
  imports: [
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    FormsModule,
  ],
  templateUrl: './insulin-dose-dialog.component.html',
  styleUrls: ['./insulin-dose-dialog.component.scss'],
})
export class InsulinDoseDialogComponent {
  protected readonly dateTime: string = toLocalDateTimeString(new Date());
  protected insulin: number | null = null;
  protected note = '';

  protected get canSave(): boolean {
    return (
      this.insulin !== null &&
      this.insulin > 0 &&
      !Number.isNaN(new Date(this.dateTime).getTime())
    );
  }

  protected getResult(): InsulinDoseDialogResult {
    return {
      cancelled: false,
      date: new Date(this.dateTime),
      insulin: this.insulin as number,
      note: this.note.trim() || null,
    };
  }
}
