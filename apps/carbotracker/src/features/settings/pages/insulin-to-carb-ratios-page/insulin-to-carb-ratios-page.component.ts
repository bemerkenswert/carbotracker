import { Component, inject, OnInit } from '@angular/core';
import {
  FormBuilder,
  FormControl,
  ReactiveFormsModule,
  Validators,
} from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatListModule } from '@angular/material/list';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { CtuiToolbarComponent } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { first } from 'rxjs';
import { InsulinToCarbRatioPageActions } from '../../+state';
import { appSettingsFeature } from '../../../../app/app.reducer';

interface InsulinToCarbRatioType {
  type: 'Breakfast ratio' | 'Lunch ratio' | 'Dinner ratio';
  control: FormControl;
}

interface InsulinToCarbRatiosFormGroup {
  showInsulinUnits: boolean;
  breakfastInsulinToCarbRatio: number | null;
  lunchInsulinToCarbRatio: number | null;
  dinnerInsulinToCarbRatio: number | null;
}

const createInsulinToCarbRatioFormGroup = () =>
  inject(FormBuilder).group<InsulinToCarbRatiosFormGroup>({
    showInsulinUnits: false,
    breakfastInsulinToCarbRatio: null,
    lunchInsulinToCarbRatio: null,
    dinnerInsulinToCarbRatio: null,
  });

@Component({
  selector: 'carbotracker-insulin-to-carb-ratios-page',
  imports: [
    CtuiToolbarComponent,
    ReactiveFormsModule,
    MatSlideToggleModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatIconModule,
    MatListModule,
  ],
  templateUrl: './insulin-to-carb-ratios-page.component.html',
  styleUrls: ['./insulin-to-carb-ratios-page.component.scss'],
})
export class InsulinToCarbRatiosPageComponent implements OnInit {
  protected readonly insulinToCarbRatiosFormGroup =
    createInsulinToCarbRatioFormGroup();
  protected readonly insulinToCarbRatios = this.getInsulinToCarbRatios();
  private readonly store = inject(Store);
  private insulinToCarbRatios$ = this.store
    .select(appSettingsFeature.selectInsulinToCarbRatios)
    .pipe(first());

  ngOnInit(): void {
    this.insulinToCarbRatios$.subscribe(
      ({
        showInsulinUnits,
        breakfastInsulinToCarbRatio,
        lunchInsulinToCarbRatio,
        dinnerInsulinToCarbRatio,
      }) =>
        this.insulinToCarbRatiosFormGroup.patchValue({
          showInsulinUnits,
          breakfastInsulinToCarbRatio,
          lunchInsulinToCarbRatio,
          dinnerInsulinToCarbRatio,
        }),
    );

    this.setValidatorsOnFormControls();
  }

  protected onSaveChanges() {
    if (this.insulinToCarbRatiosFormGroup.valid) {
      const {
        showInsulinUnits,
        breakfastInsulinToCarbRatio,
        lunchInsulinToCarbRatio,
        dinnerInsulinToCarbRatio,
      } = this.insulinToCarbRatiosFormGroup.getRawValue();
      const showUnits = !!showInsulinUnits;
      this.store.dispatch(
        InsulinToCarbRatioPageActions.saveChangesClicked({
          insulinToCarbRatios: {
            showInsulinUnits: showUnits,
            breakfastInsulinToCarbRatio,
            lunchInsulinToCarbRatio,
            dinnerInsulinToCarbRatio,
          },
        }),
      );
    }
  }

  protected onGoBack() {
    this.store.dispatch(InsulinToCarbRatioPageActions.goBackIconClicked());
  }

  private getInsulinToCarbRatios(): InsulinToCarbRatioType[] {
    return [
      {
        type: 'Breakfast ratio',
        control:
          this.insulinToCarbRatiosFormGroup.controls
            .breakfastInsulinToCarbRatio,
      },
      {
        type: 'Lunch ratio',
        control:
          this.insulinToCarbRatiosFormGroup.controls.lunchInsulinToCarbRatio,
      },
      {
        type: 'Dinner ratio',
        control:
          this.insulinToCarbRatiosFormGroup.controls.dinnerInsulinToCarbRatio,
      },
    ];
  }

  private setValidatorsOnFormControls(): void {
    this.insulinToCarbRatiosFormGroup.controls.showInsulinUnits.valueChanges.subscribe(
      (showInsulinUnits) => {
        const form = this.insulinToCarbRatiosFormGroup.controls;
        if (showInsulinUnits) {
          this.setRequiredValidator(form.breakfastInsulinToCarbRatio);
          this.setRequiredValidator(form.lunchInsulinToCarbRatio);
          this.setRequiredValidator(form.dinnerInsulinToCarbRatio);
        } else {
          this.removeRequiredValidator(form.breakfastInsulinToCarbRatio);
          this.removeRequiredValidator(form.lunchInsulinToCarbRatio);
          this.removeRequiredValidator(form.dinnerInsulinToCarbRatio);
        }
      },
    );
  }

  private setRequiredValidator(control: FormControl): void {
    control.setValidators(Validators.required);
  }

  private removeRequiredValidator(control: FormControl): void {
    control.removeValidators(Validators.required);
  }
}
