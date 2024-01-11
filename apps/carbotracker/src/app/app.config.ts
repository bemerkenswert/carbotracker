import { ApplicationConfig, inject } from '@angular/core';
import { MAT_SNACK_BAR_DEFAULT_OPTIONS } from '@angular/material/snack-bar';
import { provideAnimations } from '@angular/platform-browser/animations';
import { provideRouter, withComponentInputBinding } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideRouterStore, routerReducer } from '@ngrx/router-store';
import { Store, provideState, provideStore } from '@ngrx/store';
import { provideStoreDevtools } from '@ngrx/store-devtools';
import { filter, switchMap } from 'rxjs';
import * as authEffects from '../auth-feature/auth.effects';
import * as loginEffects from '../login-feature/login.effects';

import { authFeature } from '../auth-feature/auth.reducer';
import { provideFirebase } from '../firebase/provide-firebase';
import * as appEffects from './app.effects';

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
    provideFirebase({
      apiKey: 'AIzaSyBh6fpP_cO3C3bR-fzHR8WqHhPMURhvHqQ',
      authDomain: 'carbotracker.firebaseapp.com',
      projectId: 'carbotracker',
      storageBucket: 'carbotracker.appspot.com',
      messagingSenderId: '909622893544',
      appId: '1:909622893544:web:8f64f0bd468a035e33e25d',
      measurementId: 'G-MKN5SN9M5D',
    }),
    provideRouterStore(),
    provideState(authFeature),
    provideEffects([appEffects, authEffects, loginEffects]),
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
    { provide: MAT_SNACK_BAR_DEFAULT_OPTIONS, useValue: { duration: 5000 } },
  ],
};
