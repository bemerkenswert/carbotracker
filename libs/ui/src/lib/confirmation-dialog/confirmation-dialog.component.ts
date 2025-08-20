import { Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { ConfirmationDialogData } from './confirmation-dialog.model';

@Component({
    selector: 'ctui-confirmation-dialog',
    imports: [MatDialogModule, MatButtonModule],
    templateUrl: './confirmation-dialog.component.html',
    styleUrls: ['./confirmation-dialog.component.scss']
})
export class ConfirmationDialogComponent {
  protected readonly data: ConfirmationDialogData = inject(MAT_DIALOG_DATA);
}
