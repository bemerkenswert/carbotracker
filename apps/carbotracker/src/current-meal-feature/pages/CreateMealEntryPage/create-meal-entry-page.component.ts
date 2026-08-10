import {
  ChangeDetectionStrategy,
  Component,
  inject,
  OnInit,
} from '@angular/core';
import {
  FormControl,
  FormGroup,
  ReactiveFormsModule,
  Validators,
} from '@angular/forms';
import { MatAutocompleteModule } from '@angular/material/autocomplete';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatTooltipModule } from '@angular/material/tooltip';
import { CtuiFixedPositionDirective } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { CreateMealEntryPageComponentActions as ComponentActions } from '../../+state/actions/component.actions';
import { Product } from '../../../products-feature/product.model';
import { selectCreateMealEntryPageViewModel } from './create-meal-entry-page.selectors';

interface CreateMealEntryFormControls {
  amount: FormControl<number | null>;
  product: FormControl<Product | null>;
}

@Component({
  selector: 'carbotracker-create-meal-entry-page',
  imports: [
    CtuiFixedPositionDirective,
    ReactiveFormsModule,
    MatAutocompleteModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatTooltipModule,
  ],
  templateUrl: './create-meal-entry-page.component.html',
  styleUrls: ['./create-meal-entry-page.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class CreateMealEntryPageComponent implements OnInit {
  private readonly store = inject(Store);
  protected readonly viewModel = this.store.selectSignal(
    selectCreateMealEntryPageViewModel,
  );

  protected readonly formGroup = new FormGroup<CreateMealEntryFormControls>({
    amount: new FormControl(null, {
      validators: [Validators.required, Validators.min(1)],
    }),
    product: new FormControl<Product | null>(null, {
      validators: [Validators.required],
    }),
  });

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
    const { product, amount } = this.formGroup.getRawValue();
    this.store.dispatch(
      ComponentActions.saveClicked({
        product: product as Product,
        amount: amount as number,
      }),
    );
  }
}
