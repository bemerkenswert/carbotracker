import { ApplicationConfig, inject } from '@angular/core';
import { provideAnimations } from '@angular/platform-browser/animations';
import { provideRouter, withComponentInputBinding } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideRouterStore, routerReducer } from '@ngrx/router-store';
import { Store, provideState, provideStore } from '@ngrx/store';
import { provideStoreDevtools } from '@ngrx/store-devtools';
import { filter, switchMap } from 'rxjs';
import * as authEffects from '../auth-feature/auth.effects';
import { authFeature } from '../auth-feature/auth.reducer';
import * as appRouterEffects from './router.effects';

const isLoggedIn = () => {
  const store = inject(Store);
  return store.select(authFeature.selectIsInitialized).pipe(
    filter((isInitialized) => isInitialized),
    switchMap(() => store.select(authFeature.selectIsLoggedIn)),
  );
};

export const appConfig: ApplicationConfig = {
  providers: [
    provideAnimations(),
    provideStore({
      router: routerReducer,
    }),
    provideRouterStore(),
    provideState(authFeature),
    provideEffects([appRouterEffects, authEffects]),
    provideStoreDevtools(),
    provideRouter(
      [
        { path: '', pathMatch: 'full', redirectTo: 'app' },
        {
          path: 'app',
          canMatch: [isLoggedIn],
          loadChildren: () =>
            import('../shell-feature/shell.routes').then((m) => m.SHELL_ROUTES),
        },
        {
          path: 'login',
          loadChildren: () =>
            import('../login-feature/login.routes').then((m) => m.LOGIN_ROUTES),
        },
        {
          path: '**',
          redirectTo: 'login',
        },
      ],
      withComponentInputBinding(),
    ),
  ],
};
