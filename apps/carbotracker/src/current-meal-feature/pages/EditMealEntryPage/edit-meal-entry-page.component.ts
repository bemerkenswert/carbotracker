import { Component, effect, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatFabButton, MatIconButton } from '@angular/material/button';
import { MatIcon } from '@angular/material/icon';
import { MatFormField, MatInput, MatLabel } from '@angular/material/input';
import { ActivatedRoute } from '@angular/router';
import {
  CtuiFixedPositionDirective,
  CtuiToolbarComponent,
} from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { EditMealEntryPageComponentActions as ComponentActions } from '../../+state/actions/component.actions';
import { currentMealFeature } from '../../+state/current-meal.feature';

type FormModel = {
  amount: number | null;
};

@Component({
  selector: 'carbotracker-edit-meal-entry-page',
  templateUrl: './edit-meal-entry-page.component.html',
  styleUrls: ['./edit-meal-entry-page.component.scss'],
  imports: [
    MatFormField,
    MatLabel,
    FormsModule,
    MatIcon,
    MatInput,
    CtuiFixedPositionDirective,
    MatFabButton,
    CtuiToolbarComponent,
    MatIconButton,
  ],
})
export default class EditMealEntryPageComponent {
  private readonly store = inject(Store);
  private readonly productId: string =
    inject(ActivatedRoute).snapshot.params['id'];
  private readonly currentMealEntry = this.store.selectSignal(
    currentMealFeature.selectCurrentMealEntry(this.productId),
  );
  private readonly currentProduct = this.store.selectSignal(
    currentMealFeature.selectProductById(this.productId),
  );
  protected readonly model: FormModel = {
    amount: this.currentMealEntry()?.amount || null,
  };

  constructor() {
    this.reactToProductChanges();
  }

  protected onSubmit() {
    const product = this.currentProduct();
    if (product != null && this.model.amount && this.model.amount > 0) {
      const { amount } = this.model;
      const { name, id, carbs } = product;
      this.store.dispatch(
        ComponentActions.saveClicked({
          mealEntry: { amount, carbs, productId: id, name },
        }),
      );
    }
  }

  protected onClearCurrentMealClick() {
    const mealEntry = this.currentMealEntry();
    if (mealEntry) {
      this.store.dispatch(
        ComponentActions.deleteMealEntryClicked({ mealEntry }),
      );
    }
  }

  private reactToProductChanges() {
    effect(() => {
      const currentMealEntry = this.currentMealEntry();
      if (currentMealEntry) {
        this.model.amount = currentMealEntry.amount;
      }
    });
  }
}
