import { Injectable, inject } from '@angular/core';
import { Store } from '@ngrx/store';
import { Unsubscribe } from 'firebase/auth';
import {
  addDoc,
  collection,
  getFirestore,
  onSnapshot,
  query,
  where,
} from 'firebase/firestore';
import { from } from 'rxjs';
import { MealEntry } from '../../features/current-meal/current-meal.model';
import { MealLogsApiActions } from '../+state/meal-logs.actions';
import { toDateString } from '../date.util';
import {
  InsulinDose,
  MealLog,
  MealLogDocument,
  MealLogDocumentType,
  MealType,
} from '../meal-log.model';

const transformMealLogDocument = (
  id: string,
  data: unknown,
): MealLogDocument => {
  const document = data as {
    type: MealLogDocumentType;
    createdAt: { toDate: () => Date };
    date: string;
    note: string | null;
    creator: string;
    mealType?: MealType;
    mealEntries?: MealEntry[];
    insulinToCarbRatio?: number;
    estimatedInsulin?: number;
    actualInsulin?: number;
    insulin?: number;
  };
  if (document.type === 'insulin-dose') {
    const insulinDose: InsulinDose = {
      id,
      type: 'insulin-dose',
      createdAt: document.createdAt?.toDate() ?? new Date(0),
      date: document.date,
      insulin: document.insulin ?? 0,
      note: document.note ?? null,
      creator: document.creator,
    };
    return insulinDose;
  }
  const mealLog: MealLog = {
    id,
    type: 'meal-log',
    createdAt: document.createdAt?.toDate() ?? new Date(0),
    date: document.date,
    mealType: document.mealType ?? 'lunch',
    mealEntries: document.mealEntries ?? [],
    insulinToCarbRatio: document.insulinToCarbRatio ?? 0,
    estimatedInsulin: document.estimatedInsulin ?? 0,
    actualInsulin: document.actualInsulin ?? 0,
    note: document.note ?? null,
    creator: document.creator,
  };
  return mealLog;
};

@Injectable({ providedIn: 'root' })
export class MealLogsService {
  private readonly store = inject(Store);
  private unsubscribe: Unsubscribe | null = null;

  public subscribeToOwnMealLogs(params: { uid: string }) {
    if (this.unsubscribe === null) {
      const mealLogsQuery = query(
        collection(getFirestore(), 'meal-logs'),
        where('creator', '==', params.uid),
      );
      this.unsubscribe = onSnapshot(
        mealLogsQuery,
        (snapshot) => {
          const mealLogs = snapshot.docs.map((document) =>
            transformMealLogDocument(document.id, document.data()),
          );
          this.store.dispatch(
            MealLogsApiActions.mealLogsCollectionChanged({ mealLogs }),
          );
        },
        (error) => {
          this.store.dispatch(MealLogsApiActions.unknownError({ error }));
        },
      );
    }
  }

  public unsubscribeFromOwnMealLogs() {
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
      this.store.dispatch(MealLogsApiActions.unsubscribedFromMealLogsStream());
    }
  }

  public createInsulinDose(params: {
    date: Date;
    insulin: number;
    note: string | null;
    uid: string;
  }) {
    return from(
      addDoc(collection(getFirestore(), 'meal-logs'), {
        type: 'insulin-dose',
        createdAt: params.date,
        date: toDateString(params.date),
        insulin: params.insulin,
        note: params.note,
        creator: params.uid,
      }),
    );
  }

  public createMealLog(params: {
    mealEntries: MealEntry[];
    mealType: MealType;
    insulinToCarbRatio: number;
    estimatedInsulin: number;
    actualInsulin: number;
    note: string | null;
    date: Date;
    uid: string;
  }) {
    return from(
      addDoc(collection(getFirestore(), 'meal-logs'), {
        type: 'meal-log',
        mealEntries: params.mealEntries,
        mealType: params.mealType,
        insulinToCarbRatio: params.insulinToCarbRatio,
        estimatedInsulin: params.estimatedInsulin,
        actualInsulin: params.actualInsulin,
        note: params.note,
        date: toDateString(params.date),
        createdAt: params.date,
        creator: params.uid,
      }),
    );
  }
}
