import { ApplicationConfig, inject, isDevMode } from '@angular/core';
import { MAT_SNACK_BAR_DEFAULT_OPTIONS } from '@angular/material/snack-bar';
import { provideAnimations } from '@angular/platform-browser/animations';
import { provideRouter, withComponentInputBinding } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideRouterStore, routerReducer } from '@ngrx/router-store';
import { Store, provideStore } from '@ngrx/store';
import { provideStoreDevtools } from '@ngrx/store-devtools';
import { filter, switchMap } from 'rxjs';

import { environment } from '../environments/environment';
import { authFeature } from '../features/auth/+state/auth.store';
import { getAuthProviders } from '../features/auth/auth.providers';
import * as appEffects from './app.effects';
import { provideServiceWorker } from '@angular/service-worker';

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
    provideStore({ router: routerReducer }),
    environment.fireBaseProvider(),
    provideRouterStore(),
    getAuthProviders(),
    provideEffects([appEffects]),
    provideStoreDevtools(),
    provideRouter(
      [
        { path: '', pathMatch: 'full', redirectTo: 'app' },
        {
          path: 'app',
          canMatch: [isLoggedIn],
          loadChildren: () => import('../shell-feature/shell.routes'),
        },
        {
          path: 'login',
          loadChildren: () => import('../features/auth/auth.routes'),
        },
        {
          path: '**',
          redirectTo: 'login',
        },
      ],
      withComponentInputBinding(),
    ),
    { provide: MAT_SNACK_BAR_DEFAULT_OPTIONS, useValue: { duration: 5000 } },
    provideServiceWorker('ngsw-worker.js', {
      enabled: !isDevMode(),
      registrationStrategy: 'registerWhenStable:30000',
    }),
  ],
};
