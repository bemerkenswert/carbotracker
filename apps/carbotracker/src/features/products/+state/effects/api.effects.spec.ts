import { TestBed } from '@angular/core/testing';
import { Action } from '@ngrx/store';
import { provideMockActions } from '@ngrx/effects/testing';
import { MockStore, provideMockStore } from '@ngrx/store/testing';
import { of, Subject, throwError } from 'rxjs';
import { ProductsService } from '../../services/products.service';
import { ProductsApiActions } from '../actions/api.actions';
import { EditProductPageComponentActions } from '../actions/component.actions';
import { productsFeature } from '../products.store';
import { updateProduct$ } from './api.effects';

const selectedProduct = {
  id: 'p1',
  name: 'spaghetti',
  creator: 'user-a',
  carbs: 25,
};

describe('updateProduct$', () => {
  let actions$: Subject<Action>;
  let store: MockStore;
  let productsService: jest.Mocked<ProductsService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    productsService = {
      updateProduct: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<ProductsService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [
            {
              selector: productsFeature.selectCurrentProduct,
              value: selectedProduct,
            },
          ],
        }),
        { provide: ProductsService, useValue: productsService },
      ],
    });

    store = TestBed.inject(MockStore);
  });

  it('merges the existing product with the changed product and updates it', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      updateProduct$().subscribe((action) => results.push(action)),
    );

    actions$.next(
      EditProductPageComponentActions.saveProductClicked({
        changedProduct: { name: 'rigatoni', carbs: 30 },
      }),
    );

    expect(productsService.updateProduct).toHaveBeenCalledWith({
      ...selectedProduct,
      ...{ name: 'rigatoni', carbs: 30 },
    });
    expect(results).toEqual([ProductsApiActions.updatingProductSuccessful()]);
  });

  it('dispatches updatingProductFailed when the update fails', () => {
    productsService.updateProduct.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      updateProduct$().subscribe((action) => results.push(action)),
    );

    actions$.next(
      EditProductPageComponentActions.saveProductClicked({
        changedProduct: { name: 'rigatoni', carbs: 30 },
      }),
    );

    expect(results).toEqual([
      ProductsApiActions.updatingProductFailed({ error: expect.any(Error) }),
    ]);
  });

  it('does nothing when there is no selected product', () => {
    store.overrideSelector(productsFeature.selectCurrentProduct, null);
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      updateProduct$().subscribe((action) => results.push(action)),
    );

    actions$.next(
      EditProductPageComponentActions.saveProductClicked({
        changedProduct: { name: 'rigatoni', carbs: 30 },
      }),
    );

    expect(productsService.updateProduct).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });
});
