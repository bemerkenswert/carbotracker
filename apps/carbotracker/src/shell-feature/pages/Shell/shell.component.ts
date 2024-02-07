import { CommonModule, NgFor } from '@angular/common';
import { Component, Signal, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatToolbarModule } from '@angular/material/toolbar';
import { RouterOutlet } from '@angular/router';
import { getRouterSelectors } from '@ngrx/router-store';
import { Store, createSelector } from '@ngrx/store';
import { ShellComponentActions } from '../../shell.actions';

interface NavItem {
  onClick: () => void;
  isActive: Signal<boolean>;
  icon: string;
}

const selectIsProductsRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/products'),
);

const selectIsCurrentMealRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/current-meal'),
);

const selectIsSettingsRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/settings'),
);

const getNavItems = () => {
  const store = inject(Store);
  return [
    {
      onClick: () => store.dispatch(ShellComponentActions.productsClicked()),
      isActive: store.selectSignal(selectIsProductsRoute),
      icon: 'lunch_dining',
    },
    {
      onClick: () => store.dispatch(ShellComponentActions.currentMealClicked()),
      isActive: store.selectSignal(selectIsCurrentMealRoute),
      icon: 'restaurant',
    },
    {
      onClick: () => store.dispatch(ShellComponentActions.settingsClicked()),
      isActive: store.selectSignal(selectIsSettingsRoute),
      icon: 'settings',
    },
  ];
};

@Component({
  selector: 'carbotracker-shell',
  standalone: true,
  imports: [
    CommonModule,
    MatButtonModule,
    MatIconModule,
    MatSidenavModule,
    MatToolbarModule,
    NgFor,
    RouterOutlet,
  ],
  templateUrl: './shell.component.html',
  styleUrls: ['./shell.component.scss'],
})
export class ShellComponent {
  protected readonly navItems: NavItem[] = getNavItems();
}
