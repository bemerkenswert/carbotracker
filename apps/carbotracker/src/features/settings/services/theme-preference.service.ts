import { inject, Injectable } from '@angular/core';
import { Store } from '@ngrx/store';
import {
  doc,
  DocumentSnapshot,
  getFirestore,
  onSnapshot,
  setDoc,
  Unsubscribe,
} from 'firebase/firestore';
import { from } from 'rxjs';
import { SettingsApiActions } from '../+state/actions/api.actions';
import { ThemePreference } from '../theme-preference.model';

@Injectable({ providedIn: 'root' })
export class ThemePreferenceService {
  private readonly db = getFirestore();
  private readonly path = 'settings';
  private readonly store = inject(Store);
  private unsubscribe: Unsubscribe | null = null;

  public subscribeToOwnThemePreference(params: { uid: string }) {
    if (this.unsubscribe === null) {
      this.unsubscribe = onSnapshot(
        this.getThemePreferenceDocument(params),
        (
          doc: DocumentSnapshot<Partial<{ themePreference: ThemePreference }>>,
        ) => {
          const data = doc.data();
          if (data) {
            this.store.dispatch(
              SettingsApiActions.themeCollectionChanged({
                themePreference: this.transform(data),
              }),
            );
          }
        },
        (error) => {
          this.store.dispatch(SettingsApiActions.unknownError({ error }));
        },
      );
    }
  }

  public unsubscribeFromOwnThemePreference() {
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
      this.store.dispatch(SettingsApiActions.unsubscribedFromThemeStream());
    }
  }

  public setThemePreference(params: {
    themePreference: ThemePreference;
    uid: string;
  }) {
    const document = this.getThemePreferenceDocument(params);
    return from(
      setDoc(
        document,
        { themePreference: params.themePreference },
        { merge: true },
      ),
    );
  }

  private transform(
    data: Partial<{ themePreference: ThemePreference }>,
  ): ThemePreference {
    return data.themePreference ?? 'system';
  }

  private getThemePreferenceDocument(params: { uid: string }) {
    return doc(this.db, this.path, params.uid);
  }
}
