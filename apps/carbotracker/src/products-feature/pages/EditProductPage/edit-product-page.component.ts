import {
  ChangeDetectionStrategy,
  Component,
  Input,
  effect,
  inject,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import {
  CtuiFixedPositionDirective,
  CtuiToolbarComponent,
} from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { EditProductPageComponentActions as ComponentActions } from '../../+state/actions/component.actions';
import { productsFeature } from '../../+state/products.reducer';
import { Product } from '../../product.model';

type FormModel = Pick<Product, 'name' | 'carbs'>;

@Component({
  selector: 'carbotracker-edit-product-page',
  imports: [
    CtuiFixedPositionDirective,
    FormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    CtuiToolbarComponent,
  ],
  templateUrl: './edit-product-page.component.html',
  styleUrls: ['./edit-product-page.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class EditProductPageComponent {
  private readonly store = inject(Store);
  public readonly product = this.store.selectSignal(
    productsFeature.selectCurrentProduct,
  );

  public readonly model: FormModel = {
    name: '',
    carbs: 0,
  };

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
    const exisitingProduct = this.product();
    if (exisitingProduct)
      this.store.dispatch(
        ComponentActions.saveProductClicked({
          exisitingProduct,
          changedProduct: { ...this.model },
        }),
      );
  }

  public onDeleteClicked(selectedProduct: Product) {
    this.store.dispatch(ComponentActions.deleteClicked({ selectedProduct }));
  }

  private reactToProductChanges() {
    effect(() => {
      const currentProduct = this.product();
      if (currentProduct) {
        this.model.name = currentProduct.name;
        this.model.carbs = currentProduct.carbs;
      }
    });
  }

  public onGoBack() {
    this.store.dispatch(ComponentActions.goBackIconClicked());
  }
}
