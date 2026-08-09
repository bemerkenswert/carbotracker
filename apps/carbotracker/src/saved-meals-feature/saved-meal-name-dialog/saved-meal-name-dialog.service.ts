import { inject, Injectable } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { map, Observable } from 'rxjs';
import { SavedMealNameDialogComponent } from './saved-meal-name-dialog.component';
import {
  SavedMealNameDialogData,
  SavedMealNameDialogResult,
} from './saved-meal-name-dialog.model';

@Injectable({ providedIn: 'root' })
export class SavedMealNameDialogService {
  private readonly dialog = inject(MatDialog);

  public open(): Observable<SavedMealNameDialogResult> {
    return this.dialog
      .open<
        SavedMealNameDialogComponent,
        SavedMealNameDialogData,
        SavedMealNameDialogResult
      >(SavedMealNameDialogComponent, {
        data: { title: 'Save current meal' },
      })
      .afterClosed()
      .pipe(
        map(
          (result): SavedMealNameDialogResult => result ?? { cancelled: true },
        ),
      );
  }
}
