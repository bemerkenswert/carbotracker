import { Action, Store } from '@ngrx/store';
import { of, Subject, throwError } from 'rxjs';
import { ProductsService } from '../../services/products.service';
import { ProductsApiActions } from '../actions/api.actions';
import { EditProductPageComponentActions } from '../actions/component.actions';
import { productsFeature } from '../products.reducer';
import { updateProduct$ } from './api.effects';

const selectedProduct = {
  id: 'p1',
  name: 'spaghetti',
  creator: 'user-a',
  carbs: 25,
};

const buildStore = (): Store =>
  ({
    select: jest.fn((selector) => {
      if (selector === productsFeature.selectCurrentProduct) {
        return of(selectedProduct);
      }
      return of(null);
    }),
  }) as unknown as Store;

describe('updateProduct$', () => {
  it('merges the existing product with the changed product and updates it', () => {
    const productsService = {
      updateProduct: jest.fn(() => of(undefined)),
    } as unknown as ProductsService;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    updateProduct$(
      actions$.asObservable(),
      productsService,
      buildStore(),
    ).subscribe((action) => results.push(action));

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

  it('does nothing when there is no selected product', () => {
    const productsService = {
      updateProduct: jest.fn(() => of(undefined)),
    } as unknown as ProductsService;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    updateProduct$(
      actions$.asObservable(),
      productsService,
      buildStoreWithNoProduct(),
    ).subscribe((action) => results.push(action));

    actions$.next(
      EditProductPageComponentActions.saveProductClicked({
        changedProduct: { name: 'rigatoni', carbs: 30 },
      }),
    );

    expect(productsService.updateProduct).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });

  it('dispatches updatingProductFailed when the update fails', () => {
    const productsService = {
      updateProduct: jest.fn(() => throwError(() => new Error('boom'))),
    } as unknown as ProductsService;

    const actions$ = new Subject<Action>();
    const results: Action[] = [];
    updateProduct$(
      actions$.asObservable(),
      productsService,
      buildStore(),
    ).subscribe((action) => results.push(action));

    actions$.next(
      EditProductPageComponentActions.saveProductClicked({
        changedProduct: { name: 'rigatoni', carbs: 30 },
      }),
    );

    expect(results).toEqual([
      ProductsApiActions.updatingProductFailed({ error: expect.any(Error) }),
    ]);
  });
});

const buildStoreWithNoProduct = (): Store =>
  ({
    select: jest.fn(() => of(null)),
  }) as unknown as Store;
