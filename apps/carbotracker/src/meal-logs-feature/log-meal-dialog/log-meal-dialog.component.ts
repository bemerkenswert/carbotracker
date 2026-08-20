import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatNativeDateModule } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatDialogModule, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatListModule } from '@angular/material/list';
import { MatSelectModule } from '@angular/material/select';
import { toLocalTimeString } from '../date.util';
import { MealType } from '../meal-log.model';
import {
  estimateInsulin,
  sumOfMealEntryCarbs,
} from '../../features/current-meal/current-meal.util';
import {
  LogMealDialogData,
  LogMealDialogResult,
} from './log-meal-dialog.model';

export const inferMealTypeFromTime = (date: Date): MealType => {
  const hour = date.getHours();
  if (hour >= 5 && hour <= 10) {
    return 'breakfast';
  }
  if (hour >= 11 && hour <= 16) {
    return 'lunch';
  }
  if (hour >= 17 && hour <= 21) {
    return 'dinner';
  }
  return 'night';
};

@Component({
  selector: 'carbotracker-log-meal-dialog',
  imports: [
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatDatepickerModule,
    MatNativeDateModule,
    MatSelectModule,
    MatListModule,
    FormsModule,
  ],
  templateUrl: './log-meal-dialog.component.html',
  styleUrls: ['./log-meal-dialog.component.scss'],
})
export class LogMealDialogComponent {
  private readonly data = inject<LogMealDialogData>(MAT_DIALOG_DATA);

  protected readonly showInsulinUnits = this.data.showInsulinUnits;
  protected readonly mealEntries = this.data.mealEntries;
  protected readonly mealTypes: MealType[] = [
    'breakfast',
    'lunch',
    'dinner',
    'night',
  ];
  protected date: Date = new Date();
  protected time: string = toLocalTimeString(new Date());
  protected mealType: MealType = inferMealTypeFromTime(this.date);
  protected estimatedInsulin: number = this.computeEstimate();
  protected actualInsulin: number | null = this.showInsulinUnits
    ? this.estimatedInsulin
    : null;
  protected note = '';

  protected onMealTypeChanged() {
    this.estimatedInsulin = this.computeEstimate();
    this.actualInsulin = this.estimatedInsulin;
  }

  protected get canSave(): boolean {
    return (
      this.actualInsulin !== null &&
      this.actualInsulin >= 0 &&
      !Number.isNaN(this.selectedDateTime().getTime())
    );
  }

  protected getResult(): LogMealDialogResult {
    return {
      cancelled: false,
      date: this.selectedDateTime(),
      mealType: this.mealType,
      estimatedInsulin: this.estimatedInsulin,
      actualInsulin: this.actualInsulin as number,
      note: this.note.trim() || null,
    };
  }

  private computeEstimate(): number {
    const ratio = this.data.insulinToCarbRatios[this.mealType];
    if (!ratio) {
      return 0;
    }
    return estimateInsulin(sumOfMealEntryCarbs(this.data.mealEntries), ratio);
  }

  private selectedDateTime(): Date {
    const [hours, minutes] = this.time.split(':').map(Number);
    const date = new Date(this.date);
    date.setHours(hours, minutes, 0, 0);
    return date;
  }
}
