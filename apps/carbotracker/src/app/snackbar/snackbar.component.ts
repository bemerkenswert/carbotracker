import { AsyncPipe, NgIf } from '@angular/common';
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import {
  MAT_SNACK_BAR_DATA,
  MatSnackBarModule,
} from '@angular/material/snack-bar';
import { Store } from '@ngrx/store';
import { AppRouterEffectsActions } from '../app.actions';

@Component({
  selector: 'carbotracker-snackbar',
  standalone: true,
  imports: [AsyncPipe, MatButtonModule, MatSnackBarModule, NgIf],
  templateUrl: './snackbar.component.html',
  styleUrls: ['./snackbar.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SnackbarComponent {
  private store = inject(Store);
  public snackbarData = inject(MAT_SNACK_BAR_DATA);

  onClickOnSnackbar() {
    console.log(this.snackbarData);
    this.store.dispatch(
      AppRouterEffectsActions.navigateToLoginPage(this.snackbarData.email),
    );
  }
}
