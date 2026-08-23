import { Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import {
  AbstractControl,
  FormBuilder,
  FormControl,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatAutocompleteModule } from '@angular/material/autocomplete';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatNativeDateModule } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatDialogModule, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatRadioModule } from '@angular/material/radio';
import { Store } from '@ngrx/store';
import { sportsFeature } from '../../features/sports/+state';
import { toLocalTimeString } from '../date.util';
import {
  BasalReductionMode,
  SportDialogData,
  SportDialogResult,
} from './sport-dialog.model';

const greaterThanZero = (
  control: AbstractControl<number | null>,
): ValidationErrors | null => {
  const value = control.value;
  if (value === null || value === undefined || value <= 0) {
    return { greaterThanZero: true };
  }
  return null;
};

const createSportFormGroup = (data: SportDialogData) => {
  const fb = inject(FormBuilder);
  const sportLog = data.sportLog;
  const reductionMode: BasalReductionMode =
    sportLog?.basalRate !== null && sportLog?.basalRate !== undefined
      ? 'rate'
      : sportLog?.basalReductionPercent !== null &&
          sportLog?.basalReductionPercent !== undefined
        ? 'percent'
        : 'none';
  return fb.group({
    date: new FormControl<Date>(
      sportLog?.createdAt ?? data.defaultDate ?? new Date(),
      {
        nonNullable: true,
        validators: [Validators.required],
      },
    ),
    time: new FormControl<string>(
      toLocalTimeString(sportLog?.createdAt ?? new Date()),
      {
        nonNullable: true,
        validators: [Validators.required],
      },
    ),
    duration: new FormControl<number | null>(sportLog?.duration ?? null, {
      validators: [Validators.required, greaterThanZero],
    }),
    sportName: new FormControl<string>(sportLog?.sportName ?? '', {
      nonNullable: true,
      validators: [Validators.required],
    }),
    catalogSportId: new FormControl<string | null>(null),
    saveToCatalog: new FormControl<boolean>(false, { nonNullable: true }),
    reductionMode: new FormControl<BasalReductionMode>(reductionMode, {
      nonNullable: true,
    }),
    basalRate: new FormControl<number | null>(sportLog?.basalRate ?? null),
    basalReductionPercent: new FormControl<number | null>(
      sportLog?.basalReductionPercent ?? null,
    ),
    note: new FormControl<string>(sportLog?.note ?? '', { nonNullable: true }),
  });
};

@Component({
  selector: 'carbotracker-sport-dialog',
  imports: [
    MatDialogModule,
    MatButtonModule,
    MatCheckboxModule,
    MatAutocompleteModule,
    MatFormFieldModule,
    MatInputModule,
    MatDatepickerModule,
    MatNativeDateModule,
    MatRadioModule,
    ReactiveFormsModule,
  ],
  templateUrl: './sport-dialog.component.html',
  styleUrls: ['./sport-dialog.component.scss'],
})
export class SportDialogComponent {
  private readonly data = inject<SportDialogData>(MAT_DIALOG_DATA);
  private readonly store = inject(Store);

  protected readonly isEditing = this.data.sportLog !== undefined;

  protected readonly catalogSports = this.store.selectSignal(
    sportsFeature.selectAll,
  );

  protected readonly sportForm = createSportFormGroup(this.data);

  constructor() {
    this.onReductionModeChange(this.sportForm.controls.reductionMode.value);
    if (this.isEditing) {
      this.sportForm.controls.saveToCatalog.disable();
    }
  }

  private readonly typedSportName = toSignal(
    this.sportForm.controls.sportName.valueChanges,
    { initialValue: this.sportForm.controls.sportName.value },
  );

  protected readonly filteredCatalogSports = computed(() => {
    const query = this.typedSportName().trim().toLowerCase();
    if (!query) {
      return this.catalogSports();
    }
    return this.catalogSports().filter((sport) =>
      sport.name.toLowerCase().includes(query),
    );
  });

  protected get canSave(): boolean {
    return this.sportForm.valid;
  }

  protected onCatalogSportSelected(sportName: string) {
    const sport = this.catalogSports().find(
      (sport) => sport.name === sportName,
    );
    if (sport) {
      this.sportForm.controls.catalogSportId.setValue(sport.id);
      this.sportForm.controls.saveToCatalog.setValue(false);
    }
  }

  protected onSportNameTyped() {
    const selectedSportId = this.sportForm.controls.catalogSportId.value;
    if (selectedSportId === null) {
      return;
    }
    const selectedSport = this.catalogSports().find(
      (sport) => sport.id === selectedSportId,
    );
    if (selectedSport?.name !== this.sportForm.controls.sportName.value) {
      this.sportForm.controls.catalogSportId.setValue(null);
    }
  }

  protected onReductionModeChange(mode: BasalReductionMode) {
    const rateControl = this.sportForm.controls.basalRate;
    const percentControl = this.sportForm.controls.basalReductionPercent;
    if (mode === 'rate') {
      rateControl.setValidators([Validators.required, greaterThanZero]);
      percentControl.clearValidators();
    } else if (mode === 'percent') {
      percentControl.setValidators([Validators.required, greaterThanZero]);
      rateControl.clearValidators();
    } else {
      rateControl.clearValidators();
      percentControl.clearValidators();
    }
    rateControl.updateValueAndValidity();
    percentControl.updateValueAndValidity();
  }

  protected getResult(): SportDialogResult {
    const formValue = this.sportForm.getRawValue();
    const [hours, minutes] = formValue.time.split(':').map(Number);
    const date = new Date(formValue.date);
    date.setHours(hours, minutes, 0, 0);
    return {
      cancelled: false,
      date,
      duration: formValue.duration as number,
      sportName: formValue.sportName.trim(),
      saveToCatalog: formValue.saveToCatalog,
      basalRate:
        formValue.reductionMode === 'rate' ? formValue.basalRate : null,
      basalReductionPercent:
        formValue.reductionMode === 'percent'
          ? formValue.basalReductionPercent
          : null,
      note: formValue.note.trim() || null,
    };
  }
}
