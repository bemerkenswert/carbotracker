import { Injectable, inject } from '@angular/core';
import { Store } from '@ngrx/store';
import { Unsubscribe } from 'firebase/auth';
import {
  collection,
  doc,
  getFirestore,
  onSnapshot,
  query,
  updateDoc,
  where,
} from 'firebase/firestore';
import { from } from 'rxjs';
import { ProductsApiActions } from '../+state/products.actions';
import { Product } from '../product.model';

@Injectable({ providedIn: 'root' })
export class ProductsService {
  private readonly db = getFirestore();
  private readonly products = collection(this.db, 'products');
  private readonly store = inject(Store);

  private unsubscribe: Unsubscribe | null = null;

  public subscribeToOwnProducts(params: { uid: string }) {
    if (this.unsubscribe === null) {
      const ownProductsQuery = query(
        this.products,
        where('creator', '==', params.uid)
      );

      this.unsubscribe = onSnapshot(ownProductsQuery, (querySnapshot) => {
        const products = querySnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        })) as Product[];
        this.store.dispatch(
          ProductsApiActions.productsCollectionChanged({ products })
        );
      });
    }
  }

  public updateProduct({ name, id, carbs }: Product) {
    const productRef = doc(this.db, 'products', id);
    return from(updateDoc(productRef, { name, carbs }));
  }

  public unsubscribeFromOwnProducts() {
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
      this.store.dispatch(ProductsApiActions.unsubscribedFromProductsStream());
    }
  }
}
