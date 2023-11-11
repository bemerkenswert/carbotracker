import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { CtuiFixedPositionDirective } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { CreateProductPageComponentActions as ComponentActions } from '../../+state/products.actions';
import { Product } from '../../product.model';

type FormModel = Pick<Product, 'name' | 'carbs'>;

@Component({
  selector: 'carbotracker-create-product-page',
  standalone: true,
  imports: [
    FormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    CtuiFixedPositionDirective,
  ],
  templateUrl: './create-product-page.component.html',
  styleUrls: ['./create-product-page.component.scss'],
})
export default class CreateProductPageComponent {
  private readonly store = inject(Store);

  public readonly model: FormModel = {
    name: '',
    carbs: 0,
  };

  public onSubmit() {
    this.store.dispatch(
      ComponentActions.saveProductClicked({
        newProduct: { ...this.model },
      }),
    );
  }
}
