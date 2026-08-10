import { NgClass } from '@angular/common';
import { Component, inject, Signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatTooltipModule } from '@angular/material/tooltip';
import { RouterOutlet } from '@angular/router';
import { getRouterSelectors } from '@ngrx/router-store';
import { createSelector, Store } from '@ngrx/store';
import { ShellComponentActions } from '../../shell.actions';

interface NavItem {
  onClick: () => void;
  isActive: Signal<boolean>;
  icon: string;
  label: string;
}

const selectIsProductsRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/products'),
);

const selectIsCurrentMealRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/current-meal'),
);

const selectIsSavedMealsRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/saved-meals'),
);

const selectIsHistoryRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/history'),
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
      label: 'Products',
    },
    {
      onClick: () => store.dispatch(ShellComponentActions.currentMealClicked()),
      isActive: store.selectSignal(selectIsCurrentMealRoute),
      icon: 'restaurant',
      label: 'Current meal',
    },
    {
      onClick: () => store.dispatch(ShellComponentActions.savedMealsClicked()),
      isActive: store.selectSignal(selectIsSavedMealsRoute),
      icon: 'menu_book_2',
      label: 'Saved meals',
    },
    {
      onClick: () => store.dispatch(ShellComponentActions.historyClicked()),
      isActive: store.selectSignal(selectIsHistoryRoute),
      icon: 'history',
      label: 'History',
    },
    {
      onClick: () => store.dispatch(ShellComponentActions.settingsClicked()),
      isActive: store.selectSignal(selectIsSettingsRoute),
      icon: 'settings',
      label: 'Settings',
    },
  ];
};

@Component({
  selector: 'carbotracker-shell',
  imports: [
    MatButtonModule,
    MatIconModule,
    MatSidenavModule,
    MatToolbarModule,
    MatTooltipModule,
    RouterOutlet,
    NgClass,
  ],
  templateUrl: './shell.component.html',
  styleUrls: ['./shell.component.scss'],
})
export class ShellComponent {
  protected readonly navItems: NavItem[] = getNavItems();
}
