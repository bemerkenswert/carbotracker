import { Component, computed, inject, Signal } from '@angular/core';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatIconModule } from '@angular/material/icon';
import { MatSidenavModule } from '@angular/material/sidenav';
import { RouterOutlet } from '@angular/router';
import { getRouterSelectors } from '@ngrx/router-store';
import { createSelector, Store } from '@ngrx/store';
import { ShellComponentActions } from '../../shell.actions';

type NavItemValue = 'products' | 'current-meal' | 'saved-meals' | 'settings';

interface NavItem {
  onClick: () => void;
  isActive: Signal<boolean>;
  value: NavItemValue;
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

const selectIsSettingsRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/settings'),
);

const getNavItems = (): NavItem[] => {
  const store = inject(Store);
  return [
    {
      onClick: () => store.dispatch(ShellComponentActions.productsClicked()),
      isActive: store.selectSignal(selectIsProductsRoute),
      value: 'products',
      icon: 'lunch_dining',
      label: 'Products',
    },
    {
      onClick: () => store.dispatch(ShellComponentActions.currentMealClicked()),
      isActive: store.selectSignal(selectIsCurrentMealRoute),
      value: 'current-meal',
      icon: 'restaurant',
      label: 'Current meal',
    },
    {
      onClick: () => store.dispatch(ShellComponentActions.savedMealsClicked()),
      isActive: store.selectSignal(selectIsSavedMealsRoute),
      value: 'saved-meals',
      icon: 'menu_book_2',
      label: 'Saved meals',
    },
    {
      onClick: () => store.dispatch(ShellComponentActions.settingsClicked()),
      isActive: store.selectSignal(selectIsSettingsRoute),
      value: 'settings',
      icon: 'settings',
      label: 'Settings',
    },
  ];
};

@Component({
  selector: 'carbotracker-shell',
  imports: [
    MatButtonToggleModule,
    MatIconModule,
    MatSidenavModule,
    RouterOutlet,
  ],
  templateUrl: './shell.component.html',
  styleUrls: ['./shell.component.scss'],
})
export class ShellComponent {
  protected readonly navItems: NavItem[] = getNavItems();
  protected readonly activeNavItemValue = computed(
    () => this.navItems.find((navItem) => navItem.isActive())?.value,
  );
}
