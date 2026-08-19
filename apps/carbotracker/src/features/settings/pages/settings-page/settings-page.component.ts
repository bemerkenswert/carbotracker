import { Component, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { CtuiToolbarComponent } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { map } from 'rxjs';
import { ThemeApplicationService } from '../../../../app/theme-application.service';
import { SettingsPageActions } from '../../+state';

@Component({
  selector: 'carbotracker-settings-page',
  imports: [
    MatButtonModule,
    MatIconModule,
    MatListModule,
    MatSlideToggleModule,
    CtuiToolbarComponent,
  ],
  templateUrl: './settings-page.component.html',
  styleUrls: ['./settings-page.component.scss'],
})
export class SettingsPageComponent {
  private readonly store = inject(Store);
  private readonly themeApplicationService = inject(ThemeApplicationService);

  protected readonly darkThemeEnabled = toSignal(
    this.themeApplicationService.resolvedTheme$.pipe(
      map((theme) => theme === 'dark'),
    ),
    { initialValue: false },
  );

  protected onAccountClicked() {
    this.store.dispatch(SettingsPageActions.accountClicked());
  }

  protected onInsulinToCarbRatiosClicked() {
    this.store.dispatch(SettingsPageActions.insulinToCarbRatiosClicked());
  }

  protected onDarkThemeChanged(checked: boolean) {
    this.store.dispatch(
      SettingsPageActions.themeChanged({
        themePreference: checked ? 'dark' : 'light',
      }),
    );
  }

  protected onLogoutClicked() {
    this.store.dispatch(SettingsPageActions.logoutClicked());
  }
}
