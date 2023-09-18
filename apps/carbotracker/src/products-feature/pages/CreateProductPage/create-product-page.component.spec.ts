import { ComponentFixture, TestBed } from '@angular/core/testing';
import { CreateProductPageComponent } from './create-product-page.component';

describe('CreateProductPageComponent', () => {
  let component: CreateProductPageComponent;
  let fixture: ComponentFixture<CreateProductPageComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CreateProductPageComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(CreateProductPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
