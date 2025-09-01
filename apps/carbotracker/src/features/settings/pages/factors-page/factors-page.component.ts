import { Component, inject, OnInit } from "@angular/core";
import { FormBuilder, FormControl, ReactiveFormsModule } from "@angular/forms";
import { MatButtonModule } from "@angular/material/button";
import { MatFormFieldModule } from "@angular/material/form-field";
import { MatInputModule } from "@angular/material/input";
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { CtuiToolbarComponent } from "@carbotracker/ui";
import { Store } from "@ngrx/store";
import { combineLatest, first } from "rxjs";
import { FactorsPageActions } from "../../+state";
import { factorsFeature } from "../../+state/factors.reducer";

interface InjectionType {
    type: 'Breakfast' | 'Lunch' | 'Dinner'
    control: FormControl
}

interface FactorsFormGroup {
    showInjectionUnits: boolean | null,
    breakfastFactor: number | null,
    lunchFactor: number | null,
    dinnerFactor: number | null
}

const createFactorsFormGroup = () =>
    inject(FormBuilder).group<FactorsFormGroup>({
        showInjectionUnits: false,
        breakfastFactor: null,
        lunchFactor: null,
        dinnerFactor: null
    });

@Component({
    selector: 'carbotracker-factors-page',
    imports: [CtuiToolbarComponent, ReactiveFormsModule, MatSlideToggleModule, MatButtonModule, MatFormFieldModule, MatInputModule],
    templateUrl: './factors-page.component.html',
    styleUrls: ['./factors-page.component.scss'],
})
export class FactorsPageComponent implements OnInit {
    protected readonly factorsFormGroup = createFactorsFormGroup();
    protected readonly injectionFactors = this.getInjectionFactors();
    private readonly store = inject(Store);
    private factors$ = combineLatest([
        this.store.select(factorsFeature.selectShowInjectionUnits),
        this.store.select(factorsFeature.selectBreakfastFactor),
        this.store.select(factorsFeature.selectLunchFactor),
        this.store.select(factorsFeature.selectDinnerFactor)
    ]).pipe(first())

    ngOnInit(): void {
        this.factors$.subscribe(([showInjectionUnits, breakfastFactor, lunchFactor, dinnerFactor]) =>
            this.factorsFormGroup.setValue({ showInjectionUnits, breakfastFactor, lunchFactor, dinnerFactor }))
    }

    protected onSaveChanges() {
        const { showInjectionUnits, breakfastFactor, lunchFactor, dinnerFactor } = this.factorsFormGroup.getRawValue();
        this.store.dispatch(FactorsPageActions.saveChangesClicked({
            showInjectionUnits, breakfastFactor, lunchFactor, dinnerFactor
        }));
    }

    protected onGoBack() {
        this.store.dispatch(FactorsPageActions.goBackIconClicked());
    }

    private getInjectionFactors(): InjectionType[] {
        return [
            {
                type: 'Breakfast',
                control: this.factorsFormGroup.controls.breakfastFactor
            },
            {
                type: 'Lunch',
                control: this.factorsFormGroup.controls.lunchFactor
            },
            {
                type: 'Dinner',
                control: this.factorsFormGroup.controls.dinnerFactor
            },
        ];
    };
} 
