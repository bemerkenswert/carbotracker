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
import { SettingsApiActions } from '../+state';
import { InsulinToCarbRatio } from '../insulin-to-carb-ratio.model';

@Injectable({ providedIn: 'root' })
export class InsulinToCarbRatiosService {
  private readonly db = getFirestore();
  private readonly path = 'settings';
  private readonly store = inject(Store);
  private unsubscribe: Unsubscribe | null = null;

  public subscribeToOwnInsulinToCarbRatios(params: { uid: string }) {
    if (this.unsubscribe === null) {
      this.unsubscribe = onSnapshot(
        this.getInsulinToCarbRatiosDocument(params),
        (
          doc: DocumentSnapshot<
            Partial<{ insulinToCarbRatios: InsulinToCarbRatio }>
          >,
        ) => {
          const data = doc.data();
          if (data) {
            this.transform(data);
            this.store.dispatch(
              SettingsApiActions.insulinToCarbRatiosCollectionChanged({
                insulinToCarbRatios: this.transform(data),
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

  public unsubscribeFromOwnInsulinToCarbRatios() {
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
      this.store.dispatch(
        SettingsApiActions.unsubscribedFromInsulinToCarbRatiosStream(),
      );
    }
  }

  public setInsulinToCarbRatios(params: {
    insulinToCarbRatios: InsulinToCarbRatio;
    uid: string;
  }) {
    const document = this.getInsulinToCarbRatiosDocument(params);
    return from(
      setDoc(document, { insulinToCarbRatios: params.insulinToCarbRatios }),
    );
  }

  private transform(
    data: Partial<{ insulinToCarbRatios: InsulinToCarbRatio }>,
  ): InsulinToCarbRatio {
    return {
      showInsulinUnits: data.insulinToCarbRatios?.showInsulinUnits ?? false,
      breakfast: data.insulinToCarbRatios?.breakfast ?? null,
      lunch: data.insulinToCarbRatios?.lunch ?? null,
      dinner: data.insulinToCarbRatios?.dinner ?? null,
    };
  }

  private getInsulinToCarbRatiosDocument(params: { uid: string }) {
    return doc(this.db, this.path, params.uid);
  }
}
