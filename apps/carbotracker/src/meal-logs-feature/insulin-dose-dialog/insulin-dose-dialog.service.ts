import { Injectable, inject } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { map, Observable } from 'rxjs';
import { InsulinDoseDialogComponent } from './insulin-dose-dialog.component';
import { InsulinDoseDialogResult } from './insulin-dose-dialog.model';

@Injectable({ providedIn: 'root' })
export class InsulinDoseDialogService {
  private readonly dialog = inject(MatDialog);

  public open(): Observable<InsulinDoseDialogResult> {
    return this.dialog
      .open<InsulinDoseDialogComponent, object, InsulinDoseDialogResult>(
        InsulinDoseDialogComponent,
        { data: {} },
      )
      .afterClosed()
      .pipe(
        map((result): InsulinDoseDialogResult => result ?? { cancelled: true }),
      );
  }
}
