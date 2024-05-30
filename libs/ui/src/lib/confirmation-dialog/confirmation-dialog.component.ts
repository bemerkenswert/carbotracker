import { Component } from '@angular/core';

@Component({
  selector: 'ctui-confirmation-dialog',
  standalone: true,
})
export class ConfirmationDialogComponent {
    onAbortClick() {
        console.log('test')
    }
    
    onConfirmClick() {
        console.log('test')
    }
}
