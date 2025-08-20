import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import {
  FormBuilder,
  FormControl,
  ReactiveFormsModule,
  Validators,
} from '@angular/forms';

import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { CtuiToolbarComponent } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { SignUpFormComponentActions } from '../../+state/actions/component.actions';
import { PasswordLengthValidator } from '../../form/password-length.validator';

const createRegisterFormGroup = () =>
  inject(FormBuilder).group({
    email: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required],
    }),
    password: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, PasswordLengthValidator],
    }),
  });

@Component({
    selector: 'carbotracker-sign-up-form',
    imports: [
        MatButtonModule,
        MatDialogModule,
        MatFormFieldModule,
        MatInputModule,
        ReactiveFormsModule,
        CtuiToolbarComponent,
    ],
    templateUrl: './sign-up-form.component.html',
    styleUrls: ['./sign-up-form.component.scss'],
    changeDetection: ChangeDetectionStrategy.OnPush
})
export class SignUpFormComponent {
  private readonly store = inject(Store);
  protected readonly signUpFormGroup = createRegisterFormGroup();

  protected onSignUp() {
    const formValue = this.signUpFormGroup.getRawValue();
    this.store.dispatch(SignUpFormComponentActions.signUpClicked(formValue));
  }

  protected onGoBack() {
    this.store.dispatch(SignUpFormComponentActions.goBackClicked());
  }
}
