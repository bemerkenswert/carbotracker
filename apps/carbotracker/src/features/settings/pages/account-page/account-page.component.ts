import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { CtuiToolbarComponent } from '@carbotracker/ui';
import { Store } from '@ngrx/store';
import { take } from 'rxjs';
import { AccountPageActions } from '../../+state';
import { authFeature } from '../../../auth/+state';

const createAccountFormGroup = () =>
  inject(FormBuilder).nonNullable.group({
    email: '',
  });

@Component({
  selector: 'carbotracker-account-page',
  standalone: true,
  imports: [
    MatButtonModule,
    MatInputModule,
    MatFormFieldModule,
    ReactiveFormsModule,
    CtuiToolbarComponent,
  ],
  templateUrl: './account-page.component.html',
  styleUrls: ['./account-page.component.scss'],
})
export class AccountPageComponent implements OnInit {
  protected readonly accountFormGroup = createAccountFormGroup();
  private readonly store = inject(Store);
  private readonly email$ = this.store
    .select(authFeature.selectEmail)
    .pipe(take(1));

  public ngOnInit(): void {
    this.email$.subscribe((email) => {
      if (email) {
        this.accountFormGroup.controls.email.setValue(email);
      }
    });
  }

  protected onSaveChanges() {
    const { email } = this.accountFormGroup.getRawValue();
    this.store.dispatch(AccountPageActions.saveChangesClicked({ email }));
  }

  protected onFocusPasswordInput() {
    this.store.dispatch(AccountPageActions.passwordInputFocused());
  }

  protected onGoBack() {
    this.store.dispatch(AccountPageActions.goBackIconClicked());
  }
}
