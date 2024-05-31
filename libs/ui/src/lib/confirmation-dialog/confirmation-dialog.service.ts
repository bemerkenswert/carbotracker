import { Injectable, inject } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { Observable } from 'rxjs';
import { ConfirmationDialogComponent } from './confirmation-dialog.component';
import {
  ConfirmationDialogData,
  ConfirmationDialogResult,
} from './confirmation-dialog.model';

@Injectable({ providedIn: 'root' })
export class ConfirmationDialogService {
  private readonly dialog = inject(MatDialog);

  public openDeleteConfirmationDialog(
    element: string,
  ): Observable<ConfirmationDialogResult | undefined> {
    return this.dialog
      .open<
        ConfirmationDialogComponent,
        ConfirmationDialogData,
        ConfirmationDialogResult
      >(ConfirmationDialogComponent, {
        data: {
          title: 'Confirm deletion',
          content: `Are you sure you want to delete ${element}?`,
        },
      })
      .afterClosed();
  }
}
