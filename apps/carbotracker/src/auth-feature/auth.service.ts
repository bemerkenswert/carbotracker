import { Injectable, OnDestroy, inject } from '@angular/core';
import { Store } from '@ngrx/store';
import {
  Unsubscribe,
  getAuth,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { from } from 'rxjs';
import { FirebaseService } from '../app/firebase.service';
import { AuthApiActions } from './auth.actions';

@Injectable({ providedIn: 'root' })
export class AuthService implements OnDestroy {
  private readonly fireBaseService = inject(FirebaseService);
  private readonly auth = getAuth();
  private readonly store = inject(Store);
  private readonly unsubscribe: Unsubscribe;

  constructor() {
    this.unsubscribe = this.subscribeToStateChanges();
  }

  public login(loginData: { email: string; password: string }) {
    return from(
      signInWithEmailAndPassword(this.auth, loginData.email, loginData.password)
    );
  }
  public logout() {
    return from(signOut(this.auth));
  }

  public ngOnDestroy(): void {
    this.unsubscribe();
  }

  private subscribeToStateChanges() {
    return this.auth.onAuthStateChanged((user) => {
      if (user) {
        this.store.dispatch(AuthApiActions.userIsLoggedIn({ uid: user.uid }));
      } else {
        this.store.dispatch(AuthApiActions.userIsLoggedOut());
      }
    });
  }
}
