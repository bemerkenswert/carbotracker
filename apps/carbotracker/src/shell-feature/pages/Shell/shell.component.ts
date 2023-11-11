import { AsyncPipe, NgFor, NgIf } from '@angular/common';
import { Component, Signal, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatToolbarModule } from '@angular/material/toolbar';
import { RouterLinkActive, RouterOutlet } from '@angular/router';
import { getRouterSelectors } from '@ngrx/router-store';
import { Store, createSelector } from '@ngrx/store';
import { isHandset } from '../../../util/breakpoint';
import { ShellComponentActions } from '../../shell.actions';

interface NavItem {
  onClick: () => void;
  isActive: Signal<boolean>;
  name: string;
}

const selectIsProductsRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/products'),
);

const selectIsCurrentMealRoute = createSelector(
  getRouterSelectors().selectUrl,
  (url): boolean => url.startsWith('/app/current-meal'),
);

const getNavItems = () => {
  const store = inject(Store);
  return [
    {
      name: 'products',
      onClick: () => store.dispatch(ShellComponentActions.productsClicked()),
      isActive: store.selectSignal(selectIsProductsRoute),
    },
    {
      name: 'current meal',
      onClick: () => store.dispatch(ShellComponentActions.currentMealClicked()),
      isActive: store.selectSignal(selectIsCurrentMealRoute),
    },
  ];
};

@Component({
  selector: 'carbotracker-shell',
  standalone: true,
  imports: [
    AsyncPipe,
    MatButtonModule,
    MatIconModule,
    MatListModule,
    MatSidenavModule,
    MatToolbarModule,
    NgFor,
    NgIf,
    RouterLinkActive,
    RouterOutlet,
  ],
  templateUrl: './shell.component.html',
  styleUrls: ['./shell.component.scss'],
})
export class ShellComponent {
  protected readonly isHandset = isHandset();
  protected readonly navItems: NavItem[] = getNavItems();
}
