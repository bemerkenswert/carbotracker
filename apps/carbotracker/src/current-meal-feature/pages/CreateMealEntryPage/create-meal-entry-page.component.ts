import {
  ChangeDetectionStrategy,
  Component,
  OnInit,
  inject,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatAutocompleteModule } from '@angular/material/autocomplete';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { CtuiFixedPositionDirective } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { CreateMealEntryPageComponentActions as ComponentActions } from '../../+state/current-meal.actions';
import { Product } from '../../../products-feature/product.model';
import { selectFilteredProducts } from './create-meal-entry-page.selectors';

type FormModel = {
  amount: number;
  product: Product | null;
};

@Component({
  selector: 'carbotracker-create-meal-entry-page',
  standalone: true,
  imports: [
    CtuiFixedPositionDirective,
    FormsModule,
    MatAutocompleteModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
  ],
  templateUrl: './create-meal-entry-page.component.html',
  styleUrls: ['./create-meal-entry-page.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class CreateMealEntryPageComponent implements OnInit {
  private readonly store = inject(Store);
  protected readonly filteredProducts = this.store.selectSignal(
    selectFilteredProducts,
  );
  public readonly model: FormModel = {
    amount: 0,
    product: null,
  };

  public ngOnInit(): void {
    this.store.dispatch(ComponentActions.enteredCreateMealEntryPage());
  }

  public onFilterChange(event: Event) {
    if (event.target instanceof HTMLInputElement) {
      const productSearchTerm = event.target.value;
      this.store.dispatch(
        ComponentActions.productSearchTermChanged({ productSearchTerm }),
      );
    }
  }

  public displayProduct(product: Product | null): string {
    return product?.name ?? '';
  }

  public onSubmit() {
    if (this.model.product && this.model.amount > 0) {
      const { amount, product } = this.model;
      const { name, id, carbs } = product;
      this.store.dispatch(
        ComponentActions.saveClicked({
          mealEntry: { amount, carbs, productId: id, name },
        }),
      );
    }
  }
}
