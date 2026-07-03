import { TestBed } from '@angular/core/testing';
import { MockStore, provideMockStore } from '@ngrx/store/testing';
import { authFeature } from '../../../auth/+state/auth.store';
import { AccountPageActions } from '../../+state/actions/component.actions';
import { AccountPageComponent } from './account-page.component';

describe(AccountPageComponent.name, () => {
  let fixture: ReturnType<typeof TestBed.createComponent<AccountPageComponent>>;
  let component: AccountPageComponent;
  let store: MockStore;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AccountPageComponent],
      providers: [
        provideMockStore({
          selectors: [
            { selector: authFeature.selectEmail, value: 'person@example.com' },
          ],
        }),
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AccountPageComponent);
    component = fixture.componentInstance;
    store = TestBed.inject(MockStore);
    jest.spyOn(store, 'dispatch');
    fixture.detectChanges();
  });

  it('disables save immediately after submit', () => {
    fixture.nativeElement
      .querySelector('form')
      .dispatchEvent(new Event('submit'));
    fixture.detectChanges();

    expect(component['isSaveDisabled']).toBe(true);
    expect(store.dispatch).toHaveBeenCalledWith(
      AccountPageActions.saveChangesClicked({ email: 'person@example.com' }),
    );
  });

  it('enables save again on input click', () => {
    component['onSaveChanges']();
    fixture.detectChanges();

    fixture.nativeElement
      .querySelector('input')
      .dispatchEvent(new Event('click'));
    fixture.detectChanges();

    expect(component['isSaveDisabled']).toBe(false);
  });
});
