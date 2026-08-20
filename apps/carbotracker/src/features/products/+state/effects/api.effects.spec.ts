import { TestBed } from '@angular/core/testing';
import { Action } from '@ngrx/store';
import { provideMockActions } from '@ngrx/effects/testing';
import { MockStore, provideMockStore } from '@ngrx/store/testing';
import { of, Subject, throwError } from 'rxjs';
import { take } from 'rxjs/operators';
import { authFeature } from '../../../auth/+state/auth.store';
import { ProductsService } from '../../services/products.service';
import { ProductsApiActions } from '../actions/api.actions';
import {
  CreateProductPageComponentActions,
  EditProductPageComponentActions,
} from '../actions/component.actions';
import { DeleteProductConfirmationDialogActions } from '../actions/dialog.actions';
import { productsFeature } from '../products.store';
import { createProduct$, deleteProduct$, updateProduct$ } from './api.effects';

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
      updateProduct$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
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
      updateProduct$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
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
      updateProduct$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
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

describe('deleteProduct$', () => {
  let actions$: Subject<Action>;
  let productsService: jest.Mocked<ProductsService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    productsService = {
      deleteProduct: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<ProductsService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        { provide: ProductsService, useValue: productsService },
      ],
    });
  });

  it('deletes the selected product and dispatches deletingProductSuccessful', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      deleteProduct$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      DeleteProductConfirmationDialogActions.confirmClicked({
        selectedProduct,
      }),
    );

    expect(productsService.deleteProduct).toHaveBeenCalledWith('p1');
    expect(results).toEqual([ProductsApiActions.deletingProductSuccessful()]);
  });

  it('dispatches deletingProductFailed when the delete fails', () => {
    productsService.deleteProduct.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      deleteProduct$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      DeleteProductConfirmationDialogActions.confirmClicked({
        selectedProduct,
      }),
    );

    expect(results).toEqual([
      ProductsApiActions.deletingProductFailed({ error: expect.any(Error) }),
    ]);
  });
});

describe('createProduct$', () => {
  let actions$: Subject<Action>;
  let store: MockStore;
  let productsService: jest.Mocked<ProductsService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    productsService = {
      createProduct: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<ProductsService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [{ selector: authFeature.selectUserId, value: 'user-a' }],
        }),
        { provide: ProductsService, useValue: productsService },
      ],
    });

    store = TestBed.inject(MockStore);
  });

  it('creates the product with the user id as creator and dispatches creatingProductSuccessful', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      createProduct$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      CreateProductPageComponentActions.saveProductClicked({
        newProduct: { name: 'spaghetti', carbs: 25 },
      }),
    );

    expect(productsService.createProduct).toHaveBeenCalledWith({
      name: 'spaghetti',
      carbs: 25,
      creator: 'user-a',
    });
    expect(results).toEqual([ProductsApiActions.creatingProductSuccessful()]);
  });

  it('dispatches creatingProductFailed with the error payload when the create fails', () => {
    productsService.createProduct.mockReturnValue(
      throwError(() => new Error('boom')),
    );
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      createProduct$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      CreateProductPageComponentActions.saveProductClicked({
        newProduct: { name: 'spaghetti', carbs: 25 },
      }),
    );

    expect(results).toEqual([
      ProductsApiActions.creatingProductFailed({ error: expect.any(Error) }),
    ]);
  });

  it('does nothing when there is no user id', () => {
    store.overrideSelector(authFeature.selectUserId, null);
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      createProduct$()
        .pipe(take(1))
        .subscribe((action) => results.push(action)),
    );

    actions$.next(
      CreateProductPageComponentActions.saveProductClicked({
        newProduct: { name: 'spaghetti', carbs: 25 },
      }),
    );

    expect(productsService.createProduct).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });
});
