import { ApplicationConfig } from '@angular/core';
import { provideAnimations } from '@angular/platform-browser/animations';
import { provideRouter, withDebugTracing } from '@angular/router';
import { provideEffects } from '@ngrx/effects';
import { provideStore } from '@ngrx/store';
import { provideStoreDevtools } from '@ngrx/store-devtools';

export const appConfig: ApplicationConfig = {
  providers: [
    provideEffects(),
    provideStore(),
    provideAnimations(),
    provideStoreDevtools(),
    provideRouter(
      [
        { path: '', pathMatch: 'full', redirectTo: 'login' },
        {
          path: 'login',
          loadChildren: () =>
            import('../login-feature/login.routes').then((m) => m.LOGIN_ROUTES),
        },
      ],
      withDebugTracing()
    ),
  ],
};
