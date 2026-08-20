import { Injectable, inject } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { map, Observable } from 'rxjs';
import { EditMealLogDialogComponent } from './edit-meal-log-dialog.component';
import {
  EditMealLogDialogData,
  EditMealLogDialogResult,
} from './edit-meal-log-dialog.model';

@Injectable({ providedIn: 'root' })
export class EditMealLogDialogService {
  private readonly dialog = inject(MatDialog);

  public open(
    data: EditMealLogDialogData,
  ): Observable<EditMealLogDialogResult> {
    return this.dialog
      .open<
        EditMealLogDialogComponent,
        EditMealLogDialogData,
        EditMealLogDialogResult
      >(EditMealLogDialogComponent, { data })
      .afterClosed()
      .pipe(
        map((result): EditMealLogDialogResult => result ?? { cancelled: true }),
      );
  }
}
