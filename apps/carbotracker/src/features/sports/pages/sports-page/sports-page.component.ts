import {
  ChangeDetectionStrategy,
  Component,
  OnDestroy,
  OnInit,
  inject,
} from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatTooltipModule } from '@angular/material/tooltip';
import {
  CtuiFixedPositionDirective,
  CtuiToolbarComponent,
} from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import {
  SportsPageComponentActions as ComponentActions,
  sportsFeature,
} from '../../+state';
import { Sport } from '../../sport.model';
@Component({
  selector: 'carbotracker-sports-page',
  imports: [
    MatButtonModule,
    MatIconModule,
    MatListModule,
    MatTooltipModule,
    CtuiFixedPositionDirective,
    CtuiToolbarComponent,
  ],
  templateUrl: './sports-page.component.html',
  styleUrls: ['./sports-page.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SportsPageComponent implements OnInit, OnDestroy {
  private readonly store = inject(Store);
  protected readonly sports = this.store.selectSignal(sportsFeature.selectAll);

  public ngOnInit(): void {
    this.store.dispatch(ComponentActions.enteredSportsPage());
  }

  public ngOnDestroy(): void {
    this.store.dispatch(ComponentActions.leftSportsPage());
  }

  protected onAddClick() {
    this.store.dispatch(ComponentActions.addClicked());
  }

  protected onSportClick(sport: Sport): void {
    this.store.dispatch(ComponentActions.sportClicked({ sport }));
  }
}
