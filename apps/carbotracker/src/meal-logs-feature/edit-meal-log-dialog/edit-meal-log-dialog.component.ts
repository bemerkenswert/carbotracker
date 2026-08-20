import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatNativeDateModule } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatDialogModule, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { toLocalTimeString } from '../date.util';
import { MealType } from '../meal-log.model';
import {
  EditMealLogDialogData,
  EditMealLogDialogResult,
} from './edit-meal-log-dialog.model';

@Component({
  selector: 'carbotracker-edit-meal-log-dialog',
  imports: [
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatDatepickerModule,
    MatNativeDateModule,
    MatSelectModule,
    FormsModule,
  ],
  templateUrl: './edit-meal-log-dialog.component.html',
  styleUrls: ['./edit-meal-log-dialog.component.scss'],
})
export class EditMealLogDialogComponent {
  private readonly data = inject<EditMealLogDialogData>(MAT_DIALOG_DATA);

  protected readonly estimatedInsulin = this.data.mealLog.estimatedInsulin;
  protected readonly mealTypes: MealType[] = [
    'breakfast',
    'lunch',
    'dinner',
    'night',
  ];
  protected date: Date = this.data.mealLog.createdAt;
  protected time: string = toLocalTimeString(this.data.mealLog.createdAt);
  protected mealType: MealType = this.data.mealLog.mealType;
  protected actualInsulin: number = this.data.mealLog.actualInsulin;
  protected note = this.data.mealLog.note ?? '';

  protected get canSave(): boolean {
    return (
      this.actualInsulin >= 0 &&
      !Number.isNaN(this.selectedDateTime().getTime())
    );
  }

  protected getResult(): EditMealLogDialogResult {
    return {
      cancelled: false,
      date: this.selectedDateTime(),
      mealType: this.mealType,
      actualInsulin: this.actualInsulin,
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
