import { isDevMode } from '@angular/core';
import { bootstrapApplication } from '@angular/platform-browser';
import { AppComponent } from './app/app.component';
import { appConfig } from './app/app.config';

if (isDevMode()) {
  console.error(
    'Product page not working after direct login, F5 fixes the issue temporarily!',
  );
}

bootstrapApplication(AppComponent, appConfig).catch((err) =>
  console.error(err),
);
