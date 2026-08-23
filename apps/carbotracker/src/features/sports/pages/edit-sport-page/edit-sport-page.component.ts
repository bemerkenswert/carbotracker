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
import { EditSportPageComponentActions as ComponentActions } from '../../+state';
import { Sport } from '../../sport.model';
import { selectEditSportPageViewModel } from './edit-sport-page.selectors';

interface EditSportFormControls {
  name: FormControl<string>;
}

@Component({
  selector: 'carbotracker-edit-sport-page',
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
  templateUrl: './edit-sport-page.component.html',
  styleUrls: ['./edit-sport-page.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class EditSportPageComponent {
  private readonly store = inject(Store);
  protected readonly viewModel = this.store.selectSignal(
    selectEditSportPageViewModel,
  );

  protected readonly formGroup = new FormGroup<EditSportFormControls>({
    name: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required],
    }),
  });

  constructor() {
    this.reactToSportChanges();
  }

  @Input()
  public set id(selectedSport: string) {
    this.store.dispatch(
      ComponentActions.selectedSportChanged({ selectedSport }),
    );
  }

  public onSubmit() {
    const { name } = this.formGroup.getRawValue();
    this.store.dispatch(
      ComponentActions.saveSportClicked({ changedSport: { name } }),
    );
  }

  public onDeleteClicked(selectedSport: Sport) {
    this.store.dispatch(ComponentActions.deleteClicked({ selectedSport }));
  }

  public onGoBack() {
    this.store.dispatch(ComponentActions.goBackIconClicked());
  }

  private reactToSportChanges() {
    effect(() => {
      const initialFormValues = this.viewModel().initialFormValues;
      if (initialFormValues) {
        this.formGroup.patchValue(initialFormValues, { emitEvent: false });
      }
    });
  }
}
