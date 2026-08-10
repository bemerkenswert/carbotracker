import { Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ThemePreferenceService } from './theme-preference.service';

@Component({
  imports: [RouterOutlet],
  selector: 'carbotracker-root',
  template: '<router-outlet></router-outlet>',
})
export class AppComponent {
  constructor() {
    inject(ThemePreferenceService);
  }
}
