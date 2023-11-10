import { Routes } from '@angular/router';
import { LoginPageComponent } from './pages/LoginPage/login-page.component';
import { SignUpPageComponent } from './pages/SignUpPage/sign-up-page.component';
import { provideEffects } from '@ngrx/effects';
import * as loginEffects from './login.effects';

export const LOGIN_ROUTES: Routes = [
  {
    path: '',
    providers: [provideEffects(loginEffects)],
    children: [
      { path: '', pathMatch: 'full', component: LoginPageComponent },
      { path: 'sign-up', component: SignUpPageComponent },
    ],
  },
];
