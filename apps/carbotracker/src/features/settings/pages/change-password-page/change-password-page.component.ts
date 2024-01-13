import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { Store } from '@ngrx/store';
import { ChangePasswordPageActions } from '../../+state';

@Component({
  selector: 'carbotracker-change-password-page',
  standalone: true,
  imports: [
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    ReactiveFormsModule,
  ],
  templateUrl: './change-password-page.component.html',
  styleUrls: ['./change-password-page.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ChangePasswordPageComponent {
  protected readonly changePasswordFormGroup = inject(
    FormBuilder,
  ).nonNullable.group({
    oldPassword: '',
    newPassword: '',
    confirmPassword: '',
  });
  private readonly store = inject(Store);

  protected onChangePassword() {
    const { oldPassword, newPassword } =
      this.changePasswordFormGroup.getRawValue();
    this.store.dispatch(
      ChangePasswordPageActions.changePasswordClicked({
        oldPassword,
        newPassword,
      }),
    );
  }
}
