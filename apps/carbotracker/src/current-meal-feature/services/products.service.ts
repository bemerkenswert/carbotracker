import { Injectable, inject } from '@angular/core';
import { Store } from '@ngrx/store';
import { Unsubscribe } from 'firebase/auth';
import {
  collection,
  getFirestore,
  onSnapshot,
  query,
  where,
} from 'firebase/firestore';
import { ProductsApiActions } from '../+state/current-meal.actions';
import { Product } from '../../products-feature/product.model';

@Injectable({ providedIn: 'root' })
export class ProductsService {
  private readonly store = inject(Store);
  private unsubscribe: Unsubscribe | null = null;

  public subscribeToOwnProducts(params: { uid: string }) {
    if (this.unsubscribe === null) {
      this.unsubscribe = onSnapshot(
        query(
          collection(getFirestore(), 'products'),
          where('creator', '==', params.uid),
        ),
        (querySnapshot) => {
          const products = querySnapshot.docs.map((doc) => ({
            id: doc.id,
            ...doc.data(),
          })) as Product[];
          this.store.dispatch(
            ProductsApiActions.productsCollectionChanged({ products }),
          );
        },
        (error) => {
          this.store.dispatch(ProductsApiActions.unknownError({ error }));
        },
      );
    }
  }

  public unsubscribeFromOwnProducts() {
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
      this.store.dispatch(ProductsApiActions.unsubscribedFromProductsStream());
    }
  }
}
