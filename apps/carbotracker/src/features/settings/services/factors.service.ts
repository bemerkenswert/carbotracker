import { Injectable } from '@angular/core';
import {
  addDoc,
  collection,
  doc,
  getFirestore,
  updateDoc,
} from 'firebase/firestore';
import { from } from 'rxjs';
import { Factors } from '../factors.model';

@Injectable({ providedIn: 'root' })
export class FactorsService {
  private readonly db = getFirestore();
  private readonly factors = collection(this.db, 'factors');

  public createFactors(factors: Factors) {
    return from(addDoc(this.factors, factors));
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
