import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatListModule } from '@angular/material/list';
import {
  CtuiFixedPositionDirective,
  CtuiToolbarComponent,
} from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { currentMealFeature } from '../../+state/current-meal.feature';
import { CurrentMealPageComponentActions as ComponentActions } from '../../+state/current-meal.actions';
import { MealEntry } from '../../current-meal.model';

@Component({
  selector: 'carbotracker-current-meal-page',
  standalone: true,
  imports: [
    NgIf,
    NgFor,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatListModule,
    CtuiFixedPositionDirective,
    CtuiToolbarComponent,
  ],
  templateUrl: './current-meal-page.component.html',
  styleUrls: ['./current-meal-page.component.scss'],
})
export class CurrentMealPageComponent implements OnInit, OnDestroy {
  private readonly store = inject(Store);
  protected readonly mealEntries = this.store.selectSignal(
    currentMealFeature.selectAllMealEntries
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

  protected onMealEntryClick(mealEntry: MealEntry): void {
    this.store.dispatch(ComponentActions.mealEntryClicked({ mealEntry }));
  }

  protected getMealEntryId(index: number, mealEntry: MealEntry) {
    return mealEntry.productId;
  }
}
