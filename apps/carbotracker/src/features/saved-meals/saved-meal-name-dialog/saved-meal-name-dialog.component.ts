import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { SavedMealNameDialogData } from './saved-meal-name-dialog.model';

@Component({
  selector: 'carbotracker-saved-meal-name-dialog',
  imports: [
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    FormsModule,
  ],
  templateUrl: './saved-meal-name-dialog.component.html',
  styleUrls: ['./saved-meal-name-dialog.component.scss'],
})
export class SavedMealNameDialogComponent {
  protected readonly data: SavedMealNameDialogData = inject(MAT_DIALOG_DATA);
  protected name = '';
}
