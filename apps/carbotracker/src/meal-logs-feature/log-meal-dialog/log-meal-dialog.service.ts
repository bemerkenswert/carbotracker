import { Injectable, inject } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { map, Observable } from 'rxjs';
import { LogMealDialogComponent } from './log-meal-dialog.component';
import {
  LogMealDialogData,
  LogMealDialogResult,
} from './log-meal-dialog.model';

@Injectable({ providedIn: 'root' })
export class LogMealDialogService {
  private readonly dialog = inject(MatDialog);

  public open(data: LogMealDialogData): Observable<LogMealDialogResult> {
    return this.dialog
      .open<LogMealDialogComponent, LogMealDialogData, LogMealDialogResult>(
        LogMealDialogComponent,
        { data },
      )
      .afterClosed()
      .pipe(
        map((result): LogMealDialogResult => result ?? { cancelled: true }),
      );
  }
}
