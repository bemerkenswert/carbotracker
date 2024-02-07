import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import {
  FormBuilder,
  FormControl,
  ReactiveFormsModule,
  ValidationErrors,
} from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { Store } from '@ngrx/store';
import { ChangePasswordPageActions } from '../../+state';
import { PasswordLengthValidator } from '../../../auth/form/password-length.validator';

const SameValueValidator = <T>(
  controlOne: FormControl<T>,
  controlTwo: FormControl<T>,
): (() => ValidationErrors | null) => {
  return () => {
    return controlOne.value === controlTwo.value ? null : { sameValue: true };
  };
};

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
  private readonly fromBuilder = inject(FormBuilder);
  private readonly newPassword = this.fromBuilder.nonNullable.control('', {
    validators: [PasswordLengthValidator],
  });
  private readonly confirmPassword = this.fromBuilder.nonNullable.control('');
  protected readonly changePasswordFormGroup = inject(
    FormBuilder,
  ).nonNullable.group(
    {
      oldPassword: '',
      newPassword: this.newPassword,
      confirmPassword: this.confirmPassword,
    },
    {
      validators: [SameValueValidator(this.newPassword, this.confirmPassword)],
    },
  );
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
