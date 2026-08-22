import { Injectable, inject } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { map, Observable } from 'rxjs';
import { SportDialogComponent } from './sport-dialog.component';
import { SportDialogData, SportDialogResult } from './sport-dialog.model';

@Injectable({ providedIn: 'root' })
export class SportDialogService {
  private readonly dialog = inject(MatDialog);

  public open(data?: SportDialogData): Observable<SportDialogResult> {
    return this.dialog
      .open<SportDialogComponent, SportDialogData, SportDialogResult>(
        SportDialogComponent,
        { data: data ?? {} },
      )
      .afterClosed()
      .pipe(map((result): SportDialogResult => result ?? { cancelled: true }));
  }
}
