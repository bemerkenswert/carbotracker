import { Injectable } from '@angular/core';
import { createUserWithEmailAndPassword, getAuth } from 'firebase/auth';
import { from } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class SignUpService {
  private readonly auth = getAuth();

  public signUp(signUpData: { email: string; password: string }) {
    return from(
      createUserWithEmailAndPassword(
        this.auth,
        signUpData.email,
        signUpData.password,
      ),
    );
  }
}
