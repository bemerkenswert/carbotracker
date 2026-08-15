import {
  ChangeDetectionStrategy,
  Component,
  Input,
  effect,
  inject,
} from '@angular/core';
import {
  FormControl,
  FormGroup,
  ReactiveFormsModule,
  Validators,
} from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatTooltipModule } from '@angular/material/tooltip';
import {
  CtuiFixedPositionDirective,
  CtuiToolbarComponent,
} from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { EditProductPageComponentActions as ComponentActions } from '../../+state';
import { Product } from '../../product.model';
import { selectEditProductPageViewModel } from './edit-product-page.selectors';

interface EditProductFormControls {
  name: FormControl<string>;
  carbs: FormControl<number>;
}

@Component({
  selector: 'carbotracker-edit-product-page',
  imports: [
    CtuiFixedPositionDirective,
    CtuiToolbarComponent,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatTooltipModule,
  ],
  templateUrl: './edit-product-page.component.html',
  styleUrls: ['./edit-product-page.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class EditProductPageComponent {
  private readonly store = inject(Store);
  protected readonly viewModel = this.store.selectSignal(
    selectEditProductPageViewModel,
  );

  protected readonly formGroup = new FormGroup<EditProductFormControls>({
    name: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required],
    }),
    carbs: new FormControl(0, {
      nonNullable: true,
      validators: [Validators.required, Validators.min(0.1)],
    }),
  });

  constructor() {
    this.reactToProductChanges();
  }

  @Input()
  public set id(selectedProduct: string) {
    this.store.dispatch(
      ComponentActions.selectedProductChanged({ selectedProduct }),
    );
  }

  public onSubmit() {
    const { name, carbs } = this.formGroup.getRawValue();
    this.store.dispatch(
      ComponentActions.saveProductClicked({ changedProduct: { name, carbs } }),
    );
  }

  public onDeleteClicked(selectedProduct: Product) {
    this.store.dispatch(ComponentActions.deleteClicked({ selectedProduct }));
  }

  public onGoBack() {
    this.store.dispatch(ComponentActions.goBackIconClicked());
  }

  private reactToProductChanges() {
    effect(() => {
      const initialFormValues = this.viewModel().initialFormValues;
      if (initialFormValues) {
        this.formGroup.patchValue(initialFormValues, { emitEvent: false });
      }
    });
  }
}
