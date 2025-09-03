import { inject, Injectable } from '@angular/core';
import { Store } from '@ngrx/store';
import {
  collection,
  doc,
  DocumentSnapshot,
  getFirestore,
  onSnapshot,
  setDoc,
  Unsubscribe,
  updateDoc,
} from 'firebase/firestore';
import { from } from 'rxjs';
import { SettingsApiActions } from '../+state';
import { Factors } from '../factors.model';

@Injectable({ providedIn: 'root' })
export class FactorsService {
  private readonly db = getFirestore();
  private readonly factors = collection(this.db, 'factors');
  private readonly store = inject(Store);
  private unsubscribe: Unsubscribe | null = null;

  public subscribeToOwnFactors(params: { uid: string }) {
    if (this.unsubscribe === null) {
      this.unsubscribe = onSnapshot(
        this.getFactorsDocument(params),
        (doc: DocumentSnapshot<Partial<Factors>>) => {
          const data = doc.data();
          if (data) {
            this.transform(data);
            this.store.dispatch(
              SettingsApiActions.factorsCollectionChanged({
                factors: this.transform(data),
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

  public unsubscribeFromOwnFactors() {
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
      this.store.dispatch(SettingsApiActions.unsubscribedFromFactorsStream());
    }
  }

  public createFactors(params: { factors: Factors; uid: string }) {
    const document = this.getFactorsDocument(params);
    return from(setDoc(document, params.factors));
  }

  private transform(data: Partial<Factors>): Factors {
    return {
      showInjectionUnits: data.showInjectionUnits ?? false,
      breakfastFactor: data.breakfastFactor ?? null,
      lunchFactor: data.lunchFactor ?? null,
      dinnerFactor: data.dinnerFactor ?? null,
      creator: data.creator ?? '',
    };
  }

  private getFactorsDocument(params: { uid: string }) {
    return doc(this.db, 'factors', params.uid);
  }

  public updateFactors({
    showInjectionUnits,
    breakfastFactor,
    lunchFactor,
    dinnerFactor,
  }: Factors) {
    const factorsRef = doc(this.db, 'factors');
    return from(
      updateDoc(factorsRef, {
        showInjectionUnits,
        breakfastFactor,
        lunchFactor,
        dinnerFactor,
      }),
    );
  }
}
