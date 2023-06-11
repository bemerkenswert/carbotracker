import { ChangeDetectionStrategy, Component } from '@angular/core';
import { MatSidenavModule } from '@angular/material/sidenav';
import { LoginFormComponent } from '../../components/LoginForm/login-form.component';
import { ReactiveFormsModule } from '@angular/forms';

@Component({
  selector: 'carbotracker-login-page',
  standalone: true,
  imports: [MatSidenavModule, ReactiveFormsModule, LoginFormComponent],
  templateUrl: './login-page.component.html',
  styleUrls: ['./login-page.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LoginPageComponent {}