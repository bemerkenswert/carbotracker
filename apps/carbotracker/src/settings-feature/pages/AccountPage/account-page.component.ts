import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatListModule } from '@angular/material/list';
import { Store } from '@ngrx/store';
import { take } from 'rxjs';
import { authFeature } from '../../../auth-feature/auth.reducer';
import { AccountPageActions } from '../../settings.actions';

const createAccountFormGroup = () =>
  inject(FormBuilder).nonNullable.group({
    email: '',
    password: '',
  });

@Component({
  selector: 'carbotracker-settings-page',
  standalone: true,
  imports: [
    MatButtonModule,
    MatIconModule,
    MatListModule,
    MatFormFieldModule,
    MatInputModule,
    ReactiveFormsModule,
  ],
  templateUrl: './account-page.component.html',
  styleUrls: ['./account-page.component.scss'],
})
export class AccountPageComponent implements OnInit {
  private store = inject(Store);
  protected readonly accountFormGroup = createAccountFormGroup();
  private email$ = this.store.select(authFeature.selectEmail).pipe(take(1));

  ngOnInit(): void {
    this.email$.subscribe((email) => {
      if (email) {
        return this.accountFormGroup.controls.email.setValue(email);
      }
    });
  }

  onSaveChanges() {
    const { email, password } = this.accountFormGroup.getRawValue();
    this.store.dispatch(
      AccountPageActions.saveChangesClicked({ email, password }),
    );
  }
}
