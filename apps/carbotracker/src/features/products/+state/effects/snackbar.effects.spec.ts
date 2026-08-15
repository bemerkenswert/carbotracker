import { MatSnackBar } from '@angular/material/snack-bar';
import { Action } from '@ngrx/store';
import { of, Subject } from 'rxjs';
import { ProductsApiActions } from '../actions/api.actions';
import {
  showCreateProductFailedSnackbar$,
  showDeleteProductFailedSnackbar$,
  showProductWasChangedSnackbar$,
  showProductWasCreatedSnackbar$,
  showProductWasDeletedSnackbar$,
  showUpdateProductFailedSnackbar$,
} from './snackbar.effects';

describe('snackbar effects', () => {
  const buildSnackBar = (): jest.Mocked<MatSnackBar> => {
    const afterOpened = jest.fn(() => of(void 0));
    return {
      open: jest.fn(() => ({ afterOpened })),
    } as unknown as jest.Mocked<MatSnackBar>;
  };

  describe('showProductWasCreatedSnackbar$', () => {
    it('shows a success snackbar when product is created', () => {
      const actions$ = new Subject<Action>();
      const snackBar = buildSnackBar();
      showProductWasCreatedSnackbar$(
        actions$.asObservable(),
        snackBar,
      ).subscribe();

      actions$.next(ProductsApiActions.creatingProductSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product was added successfully.',
      );
    });
  });

  describe('showCreateProductFailedSnackbar$', () => {
    it('shows a failure snackbar when product creation fails', () => {
      const actions$ = new Subject<Action>();
      const snackBar = buildSnackBar();
      showCreateProductFailedSnackbar$(
        actions$.asObservable(),
        snackBar,
      ).subscribe();

      actions$.next(
        ProductsApiActions.creatingProductFailed({ error: 'error' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product could not be added.',
      );
    });
  });

  describe('showProductWasChangedSnackbar$', () => {
    it('shows a success snackbar when product is updated', () => {
      const actions$ = new Subject<Action>();
      const snackBar = buildSnackBar();
      showProductWasChangedSnackbar$(
        actions$.asObservable(),
        snackBar,
      ).subscribe();

      actions$.next(ProductsApiActions.updatingProductSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product was updated successfully.',
      );
    });
  });

  describe('showUpdateProductFailedSnackbar$', () => {
    it('shows a failure snackbar when product update fails', () => {
      const actions$ = new Subject<Action>();
      const snackBar = buildSnackBar();
      showUpdateProductFailedSnackbar$(
        actions$.asObservable(),
        snackBar,
      ).subscribe();

      actions$.next(
        ProductsApiActions.updatingProductFailed({ error: 'error' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product could not be updated.',
      );
    });
  });

  describe('showProductWasDeletedSnackbar$', () => {
    it('shows a success snackbar when product is deleted', () => {
      const actions$ = new Subject<Action>();
      const snackBar = buildSnackBar();
      showProductWasDeletedSnackbar$(
        actions$.asObservable(),
        snackBar,
      ).subscribe();

      actions$.next(ProductsApiActions.deletingProductSuccessful());

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product was deleted successfully.',
      );
    });
  });

  describe('showDeleteProductFailedSnackbar$', () => {
    it('shows a failure snackbar when product deletion fails', () => {
      const actions$ = new Subject<Action>();
      const snackBar = buildSnackBar();
      showDeleteProductFailedSnackbar$(
        actions$.asObservable(),
        snackBar,
      ).subscribe();

      actions$.next(
        ProductsApiActions.deletingProductFailed({ error: 'error' }),
      );

      expect(snackBar.open).toHaveBeenCalledWith(
        'The product could not be deleted.',
      );
    });
  });
});
