import { Component, Input, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatTooltipModule } from '@angular/material/tooltip';
import { CtuiToolbarComponent } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { SavedMealPageComponentActions as ComponentActions } from '../../+state/saved-meals.actions';
import { SavedMeal } from '../../saved-meal.model';
import { selectSavedMealPageViewModel } from './saved-meal-page.selectors';

@Component({
  selector: 'carbotracker-saved-meal-page',
  imports: [
    CtuiToolbarComponent,
    MatListModule,
    MatButtonModule,
    MatIconModule,
    MatTooltipModule,
  ],
  templateUrl: './saved-meal-page.component.html',
  styleUrls: ['./saved-meal-page.component.scss'],
})
export default class SavedMealPageComponent {
  private readonly store = inject(Store);
  protected readonly viewModel = this.store.selectSignal(
    selectSavedMealPageViewModel,
  );

  @Input()
  public set id(selectedSavedMealId: string) {
    this.store.dispatch(
      ComponentActions.selectedSavedMealChanged({ selectedSavedMealId }),
    );
  }

  protected onDeleteClicked(savedMeal: SavedMeal) {
    this.store.dispatch(ComponentActions.deleteClicked({ savedMeal }));
  }
}
