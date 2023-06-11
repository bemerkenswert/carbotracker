import { ComponentFixture, TestBed } from '@angular/core/testing';
import { CurrentMealPageComponent } from './current-meal-page.component';

describe('CurrentMealPageComponent', () => {
  let component: CurrentMealPageComponent;
  let fixture: ComponentFixture<CurrentMealPageComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CurrentMealPageComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(CurrentMealPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
