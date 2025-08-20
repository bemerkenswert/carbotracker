import { Component, inject } from '@angular/core';
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
import { CreateProductPageComponentActions as ComponentActions } from '../../+state/actions/component.actions';

type FormModel = { name: string; carbs: number | null };

@Component({
    selector: 'carbotracker-create-product-page',
    imports: [
        FormsModule,
        MatButtonModule,
        MatFormFieldModule,
        MatIconModule,
        MatInputModule,
        CtuiFixedPositionDirective,
        CtuiToolbarComponent,
    ],
    templateUrl: './create-product-page.component.html',
    styleUrls: ['./create-product-page.component.scss']
})
export default class CreateProductPageComponent {
  private readonly store = inject(Store);

  public readonly model: FormModel = {
    name: '',
    carbs: null,
  };

  public onSubmit() {
    if (this.model.carbs) {
      this.store.dispatch(
        ComponentActions.saveProductClicked({
          newProduct: {
            name: this.model.name,
            carbs: this.model.carbs,
          },
        }),
      );
    }
  }

  public onGoBack() {
    this.store.dispatch(ComponentActions.goBackIconClicked());
  }
}
