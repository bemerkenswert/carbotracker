import { Component, computed, inject } from '@angular/core';
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
import { CreateSportPageComponentActions as ComponentActions } from '../../+state';
import {
  selectCreateSportPageViewModel,
  selectSportNameAlreadyExists,
} from './create-sport-page.selectors';

interface CreateSportFormControls {
  name: FormControl<string>;
}

@Component({
  selector: 'carbotracker-create-sport-page',
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
  templateUrl: './create-sport-page.component.html',
  styleUrls: ['./create-sport-page.component.scss'],
})
export default class CreateSportPageComponent {
  private readonly store = inject(Store);
  protected readonly viewModel = this.store.selectSignal(
    selectCreateSportPageViewModel,
  );
  private readonly nameAlreadyExists = this.store.selectSignal(
    selectSportNameAlreadyExists,
  );

  protected readonly formGroup = new FormGroup<CreateSportFormControls>({
    name: new FormControl(this.viewModel().initialFormValues.name, {
      nonNullable: true,
      validators: [Validators.required],
    }),
  });

  protected readonly sportNameAlreadyExists = computed(() =>
    this.nameAlreadyExists()(this.formGroup.controls.name.value),
  );

  public onSubmit() {
    const { name } = this.formGroup.getRawValue();
    this.store.dispatch(
      ComponentActions.saveSportClicked({
        newSport: { name },
      }),
    );
  }

  public onGoBack() {
    this.store.dispatch(ComponentActions.goBackIconClicked());
  }
}
