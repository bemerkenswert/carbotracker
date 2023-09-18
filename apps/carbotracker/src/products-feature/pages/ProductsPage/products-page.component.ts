import { NgFor, NgIf } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  OnDestroy,
  OnInit,
  inject,
} from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatListModule } from '@angular/material/list';
import {
  CtuiFixedPositionDirective,
  CtuiToolbarComponent,
} from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { ProductsPageComponentActions as ComponentActions } from '../../+state/products.actions';
import { productsFeature } from '../../+state/products.reducer';
import { Product } from '../../product.model';
@Component({
  selector: 'carbotracker-products-page',
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
  templateUrl: './products-page.component.html',
  styleUrls: ['./products-page.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ProductsPageComponent implements OnInit, OnDestroy {
  private readonly store = inject(Store);
  protected readonly products = this.store.selectSignal(
    productsFeature.selectAll
  );

  public ngOnInit(): void {
    this.store.dispatch(ComponentActions.enteredProductsPage());
  }

  public ngOnDestroy(): void {
    this.store.dispatch(ComponentActions.leftProductsPage());
  }

  protected onAddClick() {
    this.store.dispatch(ComponentActions.addClicked());
  }

  protected onProductClick(product: Product): void {
    this.store.dispatch(ComponentActions.productClicked({ product }));
  }

  protected getProductId(index: number, product: Product) {
    return product.id;
  }
}
