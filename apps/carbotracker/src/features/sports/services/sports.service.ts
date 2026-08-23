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
  updateDoc,
  where,
} from 'firebase/firestore';
import { from } from 'rxjs';
import { SportsApiActions } from '../+state/actions/api.actions';
import { Sport } from '../sport.model';

@Injectable({ providedIn: 'root' })
export class SportsService {
  private readonly db = getFirestore();
  private readonly sports = collection(this.db, 'sports');
  private readonly store = inject(Store);

  private unsubscribe: Unsubscribe | null = null;

  public subscribeToOwnSports(params: { uid: string }) {
    if (this.unsubscribe === null) {
      const ownSportsQuery = query(
        this.sports,
        where('creator', '==', params.uid),
      );

      this.unsubscribe = onSnapshot(
        ownSportsQuery,
        (querySnapshot) => {
          const sports = querySnapshot.docs.map((doc) => ({
            id: doc.id,
            ...doc.data(),
          })) as Sport[];
          this.store.dispatch(
            SportsApiActions.sportsCollectionChanged({ sports }),
          );
        },
        (error) => {
          this.store.dispatch({ type: 'Error', error });
        },
      );
    }
  }

  public createSport(newSport: Pick<Sport, 'name' | 'creator'>) {
    return from(addDoc(this.sports, newSport));
  }

  public updateSport({ name, id }: Sport) {
    const sportRef = doc(this.db, 'sports', id);
    return from(updateDoc(sportRef, { name }));
  }

  public deleteSport(id: string) {
    const sportRef = doc(this.db, 'sports', id);
    return from(deleteDoc(sportRef));
  }

  public unsubscribeFromOwnSports() {
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
      this.store.dispatch(SportsApiActions.unsubscribedFromSportsStream());
    }
  }
}
