import { TestBed } from '@angular/core/testing';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Action } from '@ngrx/store';
import { provideMockActions } from '@ngrx/effects/testing';
import { provideMockStore } from '@ngrx/store/testing';
import { Observable, of, Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { ProductsApiActions } from '../actions/api.actions';
import {
  CreateProductPageSnackBarActions,
  DeleteProductSnackBarActions,
  EditProductPageSnackBarActions,
} from '../actions/snackbar.actions';
import {
  showCreateProductFailedSnackbar$,
  showDeleteProductFailedSnackbar$,
  showProductWasChangedSnackbar$,
  showProductWasCreatedSnackbar$,
  showProductWasDeletedSnackbar$,
  showUpdateProductFailedSnackbar$,
} from './snackbar.effects';

describe('snackbar effects', () => {
  let actions$: Subject<Action>;
  let snackBar: jest.Mocked<MatSnackBar>;

  const run = (effect: () => Observable<Action>): Action[] => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() =>
      effect().pipe(take(1)).subscribe((action) => results.push(action)),
    );

    return results;
  };

  beforeEach(() => {
    actions$ = new Subject<Action>();
    const afterOpened = jest.fn(() => of(void 0));
    snackBar = {
      open: jest.fn(() => ({ afterOpened })),
    } as unknown as jest.Mocked<MatSnackBar>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore(),
        { provide: MatSnackBar, useValue: snackBar },
      ],
    });
  });

  describe('showProductWasCreatedSnackbar$', () => {
    it('shows a success snackbar when product is created', () => {
      const results = run(() => showProductWasCreatedSnackbar$());

      actions$.next(ProductsApiActions.creatingProductSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product was added successfully.',
      );
      expect(results).toEqual([
        CreateProductPageSnackBarActions.showCreateProductSnackbarSuccessful(),
      ]);
    });
  });

  describe('showCreateProductFailedSnackbar$', () => {
    it('shows a failure snackbar when product creation fails', () => {
      const results = run(() => showCreateProductFailedSnackbar$());

      actions$.next(
        ProductsApiActions.creatingProductFailed({ error: 'error' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product could not be added.',
      );
      expect(results).toEqual([
        CreateProductPageSnackBarActions.showCreateProductSnackbarFailure(),
      ]);
    });
  });

  describe('showProductWasChangedSnackbar$', () => {
    it('shows a success snackbar when product is updated', () => {
      const results = run(() => showProductWasChangedSnackbar$());

      actions$.next(ProductsApiActions.updatingProductSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product was updated successfully.',
      );
      expect(results).toEqual([
        EditProductPageSnackBarActions.showEditProductSnackbarSuccessful(),
      ]);
    });
  });

  describe('showUpdateProductFailedSnackbar$', () => {
    it('shows a failure snackbar when product update fails', () => {
      const results = run(() => showUpdateProductFailedSnackbar$());

      actions$.next(
        ProductsApiActions.updatingProductFailed({ error: 'error' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product could not be updated.',
      );
      expect(results).toEqual([
        EditProductPageSnackBarActions.showEditProductSnackbarFailure(),
      ]);
    });
  });

  describe('showProductWasDeletedSnackbar$', () => {
    it('shows a success snackbar when product is deleted', () => {
      const results = run(() => showProductWasDeletedSnackbar$());

      actions$.next(ProductsApiActions.deletingProductSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product was deleted successfully.',
      );
      expect(results).toEqual([
        DeleteProductSnackBarActions.showDeleteProductSnackbarSuccessful(),
      ]);
    });
  });

  describe('showDeleteProductFailedSnackbar$', () => {
    it('shows a failure snackbar when product deletion fails', () => {
      const results = run(() => showDeleteProductFailedSnackbar$());

      actions$.next(
        ProductsApiActions.deletingProductFailed({ error: 'error' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product could not be deleted.',
      );
      expect(results).toEqual([
        DeleteProductSnackBarActions.showDeleteProductSnackbarFailure(),
      ]);
    });
  });
});
