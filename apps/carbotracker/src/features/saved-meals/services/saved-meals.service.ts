import { Injectable, inject } from '@angular/core';
import { Store } from '@ngrx/store';
import { Unsubscribe } from 'firebase/auth';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getFirestore,
  onSnapshot,
  query,
  serverTimestamp,
  where,
} from 'firebase/firestore';
import { from } from 'rxjs';
import { SavedMealsApiActions } from '../+state/actions/api.actions';
import { CurrentMeal } from '../../current-meal/current-meal.model';
import { SavedMeal } from '../saved-meal.model';

const transformSavedMeal = (id: string, data: unknown): SavedMeal => {
  const savedMeal = data as {
    name: string;
    mealEntries: SavedMeal['mealEntries'];
    createdAt: {
      toDate: () => Date;
    };
  };
  return {
    id,
    name: savedMeal.name,
    mealEntries: savedMeal.mealEntries ?? [],
    createdAt: savedMeal.createdAt?.toDate() ?? new Date(0),
  };
};

@Injectable({ providedIn: 'root' })
export class SavedMealsService {
  private readonly store = inject(Store);
  private unsubscribe: Unsubscribe | null = null;

  public saveCurrentMeal(params: {
    currentMeal: CurrentMeal;
    name: string;
    uid: string;
  }) {
    return from(
      addDoc(collection(getFirestore(), 'saved-meals'), {
        name: params.name,
        creator: params.uid,
        mealEntries: params.currentMeal.mealEntries,
        createdAt: serverTimestamp(),
      }),
    );
  }

  public deleteSavedMeal(savedMealId: string) {
    return from(deleteDoc(doc(getFirestore(), 'saved-meals', savedMealId)));
  }

  public subscribeToOwnSavedMeals(params: { uid: string }) {
    if (this.unsubscribe === null) {
      const savedMealsQuery = query(
        collection(getFirestore(), 'saved-meals'),
        where('creator', '==', params.uid),
      );
      this.unsubscribe = onSnapshot(
        savedMealsQuery,
        (snapshot) => {
          const savedMeals = snapshot.docs.map((document) =>
            transformSavedMeal(document.id, document.data()),
          );
          this.store.dispatch(
            SavedMealsApiActions.savedMealsCollectionChanged({ savedMeals }),
          );
        },
        (error) => {
          this.store.dispatch(SavedMealsApiActions.unknownError({ error }));
        },
      );
    }
  }

  public unsubscribeFromOwnSavedMeals() {
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
      this.store.dispatch(
        SavedMealsApiActions.unsubscribedFromSavedMealsStream(),
      );
    }
  }
}
