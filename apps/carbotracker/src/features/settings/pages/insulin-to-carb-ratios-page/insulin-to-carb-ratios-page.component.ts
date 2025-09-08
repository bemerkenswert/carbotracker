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
import { filterNull } from '@carbotracker/utility';
import { Store } from '@ngrx/store';
import { InsulinToCarbRatiosPageActions } from '../../+state';
import { settingsFeature } from '../../../../app/app.reducer';

interface InsulinToCarbRatioPerMeal {
  mealType: 'Breakfast ratio' | 'Lunch ratio' | 'Dinner ratio';
  control: FormControl;
}

interface InsulinToCarbRatiosFormGroup {
  showInsulinUnits: boolean;
  breakfast: number | null;
  lunch: number | null;
  dinner: number | null;
}

const createInsulinToCarbRatiosFormGroup = () =>
  inject(FormBuilder).group<InsulinToCarbRatiosFormGroup>({
    showInsulinUnits: false,
    breakfast: null,
    lunch: null,
    dinner: null,
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
    createInsulinToCarbRatiosFormGroup();
  protected readonly insulinToCarbRatios = this.getInsulinToCarbRatios();
  private readonly store = inject(Store);
  private insulinToCarbRatios$ = this.store
    .select(settingsFeature.selectInsulinToCarbRatios)
    .pipe(filterNull());

  ngOnInit(): void {
    this.insulinToCarbRatios$.subscribe((insulinToCarbRatios) =>
      this.insulinToCarbRatiosFormGroup.reset(insulinToCarbRatios),
    );

    this.reactToShowSettingChanges();
  }

  protected onSaveChanges() {
    if (this.insulinToCarbRatiosFormGroup.valid) {
      const { showInsulinUnits, breakfast, lunch, dinner } =
        this.insulinToCarbRatiosFormGroup.getRawValue();
      const showUnits = !!showInsulinUnits;
      this.store.dispatch(
        InsulinToCarbRatiosPageActions.saveChangesClicked({
          insulinToCarbRatios: {
            showInsulinUnits: showUnits,
            breakfast,
            lunch,
            dinner,
          },
        }),
      );
    }
  }

  protected onGoBack() {
    this.store.dispatch(InsulinToCarbRatiosPageActions.goBackIconClicked());
  }

  private getInsulinToCarbRatios(): InsulinToCarbRatioPerMeal[] {
    return [
      {
        mealType: 'Breakfast ratio',
        control: this.insulinToCarbRatiosFormGroup.controls.breakfast,
      },
      {
        mealType: 'Lunch ratio',
        control: this.insulinToCarbRatiosFormGroup.controls.lunch,
      },
      {
        mealType: 'Dinner ratio',
        control: this.insulinToCarbRatiosFormGroup.controls.dinner,
      },
    ];
  }

  private reactToShowSettingChanges(): void {
    this.insulinToCarbRatiosFormGroup.controls.showInsulinUnits.valueChanges.subscribe(
      (showInsulinUnits) => {
        const form = this.insulinToCarbRatiosFormGroup.controls;
        if (showInsulinUnits) {
          this.setRequiredValidator(form.breakfast);
          this.setRequiredValidator(form.lunch);
          this.setRequiredValidator(form.dinner);
        } else {
          this.removeRequiredValidator(form.breakfast);
          this.removeRequiredValidator(form.lunch);
          this.removeRequiredValidator(form.dinner);
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
