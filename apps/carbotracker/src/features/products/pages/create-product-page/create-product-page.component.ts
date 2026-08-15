import { Component, inject } from '@angular/core';
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
import { CreateProductPageComponentActions as ComponentActions } from '../../+state';
import { selectCreateProductPageViewModel } from './create-product-page.selectors';

interface CreateProductFormControls {
  name: FormControl<string>;
  carbs: FormControl<number | null>;
}

@Component({
  selector: 'carbotracker-create-product-page',
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
  templateUrl: './create-product-page.component.html',
  styleUrls: ['./create-product-page.component.scss'],
})
export default class CreateProductPageComponent {
  private readonly store = inject(Store);
  protected readonly viewModel = this.store.selectSignal(
    selectCreateProductPageViewModel,
  );

  protected readonly formGroup = new FormGroup<CreateProductFormControls>({
    name: new FormControl(this.viewModel().initialFormValues.name, {
      nonNullable: true,
      validators: [Validators.required],
    }),
    carbs: new FormControl(this.viewModel().initialFormValues.carbs, {
      validators: [Validators.required, Validators.min(0.1)],
    }),
  });

  public onSubmit() {
    const { name, carbs } = this.formGroup.getRawValue();
    this.store.dispatch(
      ComponentActions.saveProductClicked({
        newProduct: { name, carbs: carbs as number },
      }),
    );
  }

  public onGoBack() {
    this.store.dispatch(ComponentActions.goBackIconClicked());
  }
}
