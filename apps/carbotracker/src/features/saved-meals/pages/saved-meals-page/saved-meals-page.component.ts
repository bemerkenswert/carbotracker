import { DecimalPipe } from '@angular/common';
import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { MatListModule } from '@angular/material/list';
import { CtuiToolbarComponent } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { SavedMealsPageComponentActions } from '../../+state';
import { SavedMeal } from '../../saved-meal.model';
import { selectSavedMealsViewModel } from './saved-meals-page.selectors';

@Component({
  selector: 'carbotracker-saved-meals-page',
  imports: [CtuiToolbarComponent, MatListModule, DecimalPipe],
  templateUrl: './saved-meals-page.component.html',
  styleUrls: ['./saved-meals-page.component.scss'],
})
export default class SavedMealsPageComponent implements OnInit, OnDestroy {
  private readonly store = inject(Store);
  protected readonly viewModel = this.store.selectSignal(
    selectSavedMealsViewModel,
  );

  public ngOnInit(): void {
    this.store.dispatch(SavedMealsPageComponentActions.enteredSavedMealsPage());
  }

  public ngOnDestroy(): void {
    this.store.dispatch(SavedMealsPageComponentActions.leftSavedMealsPage());
  }

  protected onSavedMealClick(savedMeal: SavedMeal) {
    this.store.dispatch(
      SavedMealsPageComponentActions.savedMealClicked({ savedMeal }),
    );
  }
}
