import { inject, Injectable } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { map, Observable } from 'rxjs';
import { SavedMealNameDialogComponent } from './saved-meal-name-dialog.component';
import { SavedMealNameDialogResult } from './saved-meal-name-dialog.model';

@Injectable({ providedIn: 'root' })
export class SavedMealNameDialogService {
  private readonly dialog = inject(MatDialog);

  public open(): Observable<string | undefined> {
    return this.dialog
      .open<
        SavedMealNameDialogComponent,
        { title: string },
        SavedMealNameDialogResult
      >(SavedMealNameDialogComponent, {
        data: { title: 'Save current meal' },
      })
      .afterClosed()
      .pipe(map((result) => result?.name));
  }
}
