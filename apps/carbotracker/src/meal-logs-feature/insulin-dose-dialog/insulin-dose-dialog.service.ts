import { Injectable, inject } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { map, Observable } from 'rxjs';
import { InsulinDoseDialogComponent } from './insulin-dose-dialog.component';
import {
  InsulinDoseDialogData,
  InsulinDoseDialogResult,
} from './insulin-dose-dialog.model';

@Injectable({ providedIn: 'root' })
export class InsulinDoseDialogService {
  private readonly dialog = inject(MatDialog);

  public open(
    data?: InsulinDoseDialogData,
  ): Observable<InsulinDoseDialogResult> {
    return this.dialog
      .open<
        InsulinDoseDialogComponent,
        InsulinDoseDialogData,
        InsulinDoseDialogResult
      >(InsulinDoseDialogComponent, { data: data ?? {} })
      .afterClosed()
      .pipe(
        map((result): InsulinDoseDialogResult => result ?? { cancelled: true }),
      );
  }
}
