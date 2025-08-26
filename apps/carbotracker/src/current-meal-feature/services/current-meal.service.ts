import { Injectable, inject } from '@angular/core';
import { Store } from '@ngrx/store';
import { Unsubscribe } from 'firebase/auth';
import {
  DocumentSnapshot,
  doc,
  getFirestore,
  onSnapshot,
  setDoc,
} from 'firebase/firestore';
import { from } from 'rxjs';
import { CurrentMealApiActions as ApiActions } from '../+state/current-meal.actions';
import { CurrentMeal, MealEntry } from '../current-meal.model';

@Injectable({ providedIn: 'root' })
export class CurrentMealService {
  private readonly store = inject(Store);
  private unsubscribe: Unsubscribe | null = null;

  public addMealEntry(params: {
    currentMeal: CurrentMeal;
    mealEntry: MealEntry;
    uid: string;
  }) {
    const mealEntries = [...params.currentMeal.mealEntries, params.mealEntry];
    const document = this.getCurrentMealDocument(params);
    return from(setDoc(document, { mealEntries }));
  }

  public cleanAllMealEntries(params: { uid: string }) {
    const document = this.getCurrentMealDocument(params);
    return from(setDoc(document, { mealEntries: [] }));
  }

  public subscribeToOwnCurrentMeal(params: { uid: string }) {
    if (this.unsubscribe === null) {
      this.unsubscribe = onSnapshot(
        this.getCurrentMealDocument(params),
        (doc: DocumentSnapshot<Partial<CurrentMeal>>) => {
          const data = doc.data();
          if (data) {
            this.store.dispatch(
              ApiActions.currentMealCollectionChanged({
                currentMeal: this.transform(data),
              }),
            );
          }
        },
        (error) => {
          this.store.dispatch(ApiActions.unknownError({ error }));
        },
      );
    }
  }

  public unsubscribeFromOwnCurrentMeal() {
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
      this.store.dispatch(ApiActions.unsubscribedFromCurrentMealStream());
    }
  }

  private transform(data: Partial<CurrentMeal>): CurrentMeal {
    return {
      mealEntries: data.mealEntries ?? [],
    };
  }

  private getCurrentMealDocument(params: { uid: string }) {
    return doc(getFirestore(), 'current-meals', params.uid);
  }
}
