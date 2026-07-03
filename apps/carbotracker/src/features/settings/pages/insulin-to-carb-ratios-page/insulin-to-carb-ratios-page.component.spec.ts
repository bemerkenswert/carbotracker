import { TestBed } from '@angular/core/testing';
import { MockStore, provideMockStore } from '@ngrx/store/testing';
import { settingsFeature } from '../../../../app/app.reducer';
import { InsulinToCarbRatiosPageActions } from '../../+state/actions/component.actions';
import { InsulinToCarbRatiosPageComponent } from './insulin-to-carb-ratios-page.component';

describe(InsulinToCarbRatiosPageComponent.name, () => {
  let fixture: ReturnType<
    typeof TestBed.createComponent<InsulinToCarbRatiosPageComponent>
  >;
  let component: InsulinToCarbRatiosPageComponent;
  let store: MockStore;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [InsulinToCarbRatiosPageComponent],
      providers: [
        provideMockStore({
          selectors: [
            {
              selector: settingsFeature.selectInsulinToCarbRatios,
              value: {
                showInsulinUnits: true,
                breakfast: 12,
                lunch: 15,
                dinner: 18,
              },
            },
          ],
        }),
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(InsulinToCarbRatiosPageComponent);
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
      InsulinToCarbRatiosPageActions.saveChangesClicked({
        insulinToCarbRatios: {
          showInsulinUnits: true,
          breakfast: 12,
          lunch: 15,
          dinner: 18,
        },
      }),
    );
  });

  it('enables save again on ratio input focus', () => {
    component['onSaveChanges']();
    fixture.detectChanges();

    fixture.nativeElement
      .querySelector('input[type="number"]')
      .dispatchEvent(new Event('focus'));
    fixture.detectChanges();

    expect(component['isSaveDisabled']).toBe(false);
  });
});
