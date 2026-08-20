import { DatePipe, DecimalPipe } from '@angular/common';
import {
  Component,
  OnDestroy,
  OnInit,
  Signal,
  computed,
  inject,
} from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatNativeDateModule } from '@angular/material/core';
import {
  MatCalendar,
  MatCalendarCellCssClasses,
} from '@angular/material/datepicker';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatTooltipModule } from '@angular/material/tooltip';
import {
  CtuiFixedPositionDirective,
  CtuiToolbarComponent,
} from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { HistoryPageComponentActions } from '../../+state/meal-logs.actions';
import { fromDateString, toDateString } from '../../date.util';
import { MealLogDocument } from '../../meal-log.model';
import { selectHistoryPageViewModel } from './history-page.selectors';

@Component({
  selector: 'carbotracker-history-page',
  imports: [
    CtuiToolbarComponent,
    CtuiFixedPositionDirective,
    MatCalendar,
    MatNativeDateModule,
    MatButtonModule,
    MatIconModule,
    MatListModule,
    MatTooltipModule,
    DatePipe,
    DecimalPipe,
  ],
  templateUrl: './history-page.component.html',
  styleUrls: ['./history-page.component.scss'],
})
export default class HistoryPageComponent implements OnInit, OnDestroy {
  private readonly store = inject(Store);
  protected readonly viewModel = this.store.selectSignal(
    selectHistoryPageViewModel,
  );
  protected readonly selectedDate: Signal<Date | null> = computed(() => {
    const date = this.viewModel().selectedDate;
    return date ? fromDateString(date) : null;
  });

  public ngOnInit(): void {
    this.store.dispatch(HistoryPageComponentActions.enteredHistoryPage());
    this.store.dispatch(
      HistoryPageComponentActions.dateSelected({
        date: toDateString(new Date()),
      }),
    );
  }

  public ngOnDestroy(): void {
    this.store.dispatch(HistoryPageComponentActions.leftHistoryPage());
  }

  protected onDateSelected(date: Date | null) {
    if (date) {
      this.store.dispatch(
        HistoryPageComponentActions.dateSelected({ date: toDateString(date) }),
      );
    }
  }

  protected onLogInsulinDoseClick() {
    this.store.dispatch(HistoryPageComponentActions.logInsulinDoseClicked());
  }

  protected onEntryClick(mealLog: MealLogDocument) {
    this.store.dispatch(
      mealLog.type === 'meal-log'
        ? HistoryPageComponentActions.editMealLogClicked({ mealLog })
        : HistoryPageComponentActions.editInsulinDoseClicked({ mealLog }),
    );
  }

  protected onDeleteClick(mealLog: MealLogDocument) {
    this.store.dispatch(
      HistoryPageComponentActions.deleteMealLogDocumentClicked({ mealLog }),
    );
  }

  protected onReloadClick(mealLog: MealLogDocument) {
    this.store.dispatch(
      HistoryPageComponentActions.reloadMealLogIntoMealClicked({ mealLog }),
    );
  }

  protected readonly dateClass: Signal<
    (date: Date) => MatCalendarCellCssClasses
  > = computed(() => {
    const datesWithMealLogs = this.viewModel().datesWithMealLogs;
    return (date: Date): MatCalendarCellCssClasses =>
      datesWithMealLogs.has(toDateString(date)) ? 'has-meal-log' : '';
  });
}
