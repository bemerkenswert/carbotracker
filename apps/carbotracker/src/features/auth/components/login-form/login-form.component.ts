import {
  ChangeDetectionStrategy,
  Component,
  OnInit,
  inject,
} from '@angular/core';
import {
  FormBuilder,
  FormControl,
  ReactiveFormsModule,
  Validators,
} from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSidenavModule } from '@angular/material/sidenav';
import { Store } from '@ngrx/store';
import { take } from 'rxjs';
import { authFeature } from '../../+state/auth.store';
import { LoginFormComponentActions } from '../../+state/actions/component.actions';
import { AuthService } from '../../services/auth.service';
import { PasswordLengthValidator } from '../../form/password-length.validator';

const createLoginFormGroup = () =>
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
  selector: 'carbotracker-login-form',
  standalone: true,
  imports: [
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    ReactiveFormsModule,
    MatSidenavModule,
  ],
  templateUrl: './login-form.component.html',
  styleUrls: ['./login-form.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LoginFormComponent implements OnInit {
  private readonly store = inject(Store);
  private readonly auth = inject(AuthService);
  protected readonly loginFormGroup = createLoginFormGroup();

  public ngOnInit(): void {
    this.store
      .select(authFeature.selectAlreadyExistingSignUpEmail)
      .pipe(take(1))
      .subscribe((email) => {
        if (email) {
          this.loginFormGroup.controls.email.setValue(email);
        }
      });
  }

  public onLogin() {
    const formValue = this.loginFormGroup.getRawValue();
    this.store.dispatch(LoginFormComponentActions.loginClicked(formValue));
  }

  public onLogout() {
    this.auth.logout().subscribe();
  }

  public onSignUp() {
    this.store.dispatch(LoginFormComponentActions.signUpClicked());
  }
}
