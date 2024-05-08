import { Injectable, inject } from '@angular/core';
import { Store } from '@ngrx/store';
import {
  EmailAuthProvider,
  Unsubscribe,
  User,
  createUserWithEmailAndPassword,
  getAuth,
  reauthenticateWithCredential,
  signInWithEmailAndPassword,
  signOut,
  updateEmail,
  updatePassword,
} from 'firebase/auth';
import { Observable, filter, from, of } from 'rxjs';
import { AuthApiActions } from '../+state/actions/api.actions';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly auth = getAuth();
  private readonly store = inject(Store);
  private readonly unsubscribe: Unsubscribe;

  constructor() {
    this.unsubscribe = this.subscribeToStateChanges();
  }

  public login(loginData: { email: string; password: string }) {
    return from(
      signInWithEmailAndPassword(
        this.auth,
        loginData.email,
        loginData.password,
      ),
    );
  }

  public logout() {
    return from(signOut(this.auth));
  }

  public signUp(signUpData: { email: string; password: string }) {
    return from(
      createUserWithEmailAndPassword(
        this.auth,
        signUpData.email,
        signUpData.password,
      ),
    );
  }

  public getUser(): Observable<User> {
    return of(getAuth().currentUser).pipe(
      filter((user): user is User => !!user),
    );
  }

  public updateEmail(user: User, email: string): Observable<void> {
    return from(updateEmail(user, email));
  }

  public reauthenticate(user: User, email: string, password: string) {
    const credentials = EmailAuthProvider.credential(email, password);
    return from(reauthenticateWithCredential(user, credentials));
  }

  public updatePassword(user: User, password: string): Observable<void> {
    return from(updatePassword(user, password));
  }

  private subscribeToStateChanges() {
    return this.auth.onAuthStateChanged((user) => {
      if (user) {
        this.store.dispatch(
          AuthApiActions.userIsLoggedIn({
            uid: user.uid,
            email: user.email as string,
          }),
        );
      } else {
        this.store.dispatch(AuthApiActions.userIsLoggedOut());
      }
    });
  }
}
