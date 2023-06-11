import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatSidenavModule } from '@angular/material/sidenav';
import { AuthService } from 'apps/carbotracker/src/auth-feature/auth.service';

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
export class LoginFormComponent {

  protected readonly loginFormGroup = inject(FormBuilder).group({
    email: ['', [Validators.required]],
    password: ['', [Validators.required]],
  });

  private authService = inject(AuthService);

  public onLogin() {
    this.authService.login();
  }
}
