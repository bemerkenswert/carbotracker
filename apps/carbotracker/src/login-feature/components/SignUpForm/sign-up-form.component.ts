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
import { Store } from '@ngrx/store';
import { SignUpFormComponentActions } from '../../login.actions';

const createRegisterFormGroup = () =>
  inject(FormBuilder).group({
    email: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required],
    }),
    password: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required],
    }),
  });

@Component({
  selector: 'carbotracker-sign-up-form',
  standalone: true,
  imports: [
    MatButtonModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    ReactiveFormsModule,
  ],
  templateUrl: './sign-up-form.component.html',
  styleUrls: ['./sign-up-form.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SignUpFormComponent {
  private readonly store = inject(Store);
  protected readonly signUpFormGroup = createRegisterFormGroup();

  onSignUp() {
    const formValue = this.signUpFormGroup.getRawValue();
    this.store.dispatch(SignUpFormComponentActions.signUpClicked(formValue));
  }

  onGoBack() {
    this.store.dispatch(SignUpFormComponentActions.goBackClicked());
  }
}
