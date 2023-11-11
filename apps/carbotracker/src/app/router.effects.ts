import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { AuthApiActions } from '../auth-feature/auth.actions';
import { from, switchMap } from 'rxjs';

export const navigateToProducts$ = createEffect(
  (actions$ = inject(Actions), router = inject(Router)) =>
    actions$.pipe(
      ofType(AuthApiActions.loginSuccessful),
      switchMap(() => from(router.navigate(['app', 'products']))),
    ),
  { functional: true, dispatch: false },
);
