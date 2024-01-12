import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { Store } from '@ngrx/store';
import { ChangePasswordPageActions as ComponentActions } from '../../settings.actions';
import { MatButtonModule } from '@angular/material/button';

@Component({
  selector: 'carbotracker-change-password-page',
  standalone: true,
  imports: [
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    ReactiveFormsModule,
  ],
  templateUrl: './ChangePasswordPage.component.html',
  styleUrls: ['./ChangePasswordPage.component.scss'],
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
    const formValue = this.changePasswordFormGroup.getRawValue();
    this.store.dispatch(ComponentActions.changePasswordClicked(formValue));
  }
}
