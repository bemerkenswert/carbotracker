import { Routes } from '@angular/router';
import { SportsPageComponent } from './pages/sports-page/sports-page.component';

const SPORTS_ROUTES: Routes = [
  {
    path: '',
    component: SportsPageComponent,
  },
  {
    path: 'create',
    loadComponent: () =>
      import('./pages/create-sport-page/create-sport-page.component'),
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./pages/edit-sport-page/edit-sport-page.component'),
  },
];

export default SPORTS_ROUTES;
