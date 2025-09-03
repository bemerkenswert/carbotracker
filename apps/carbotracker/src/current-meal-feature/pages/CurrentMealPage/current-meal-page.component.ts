import { AsyncPipe, DecimalPipe } from '@angular/common';
import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import {
  CtuiFixedPositionDirective,
  CtuiToolbarComponent,
} from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { CurrentMealPageComponentActions as ComponentActions } from '../../+state/current-meal.actions';
import { currentMealFeature } from '../../+state/current-meal.feature';
import { appSettingsFeature } from '../../../app/app.reducer';
import { MealEntry } from '../../current-meal.model';
import { selectSumOfCurrentMealCarbs } from './current-meal-page.selector';

@Component({
  selector: 'carbotracker-current-meal-page',
  imports: [
    CtuiFixedPositionDirective,
    CtuiToolbarComponent,
    MatButtonModule,
    MatIconModule,
    MatListModule,
    DecimalPipe,
    AsyncPipe,
  ],
  templateUrl: './current-meal-page.component.html',
  styleUrls: ['./current-meal-page.component.scss'],
})
export default class CurrentMealPageComponent implements OnInit, OnDestroy {
  private readonly store = inject(Store);
  protected readonly mealEntries = this.store.selectSignal(
    currentMealFeature.selectAllMealEntries,
  );
  protected readonly productsAvailable = this.store.selectSignal(
    currentMealFeature.selectProductsAvailableToAdd,
  );
  protected readonly sumOfCurrentMealCarbs = this.store.selectSignal(
    selectSumOfCurrentMealCarbs,
  );
  protected readonly showInjectionUnits$ = this.store.select(
    appSettingsFeature.selectShowInjectionUnits,
  );
  protected readonly injectionUnits$ = this.store.select(
    appSettingsFeature.selectInjectionUnits,
  );

  public ngOnInit(): void {
    this.store.dispatch(ComponentActions.enteredCurrentMealPage());
  }

  public ngOnDestroy(): void {
    this.store.dispatch(ComponentActions.leftCurrentMealPage());
  }

  protected onAddClick() {
    this.store.dispatch(ComponentActions.addClicked());
  }

  protected onClearCurrentMealClick() {
    this.store.dispatch(ComponentActions.clearCurrentMealClicked());
  }

  protected onMealEntryClick(mealEntry: MealEntry): void {
    this.store.dispatch(ComponentActions.mealEntryClicked({ mealEntry }));
  }
}
