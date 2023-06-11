import { ComponentFixture, TestBed } from '@angular/core/testing';
import { EditProductPageComponent } from './edit-product-page.component';

describe('EditProductPageComponent', () => {
  let component: EditProductPageComponent;
  let fixture: ComponentFixture<EditProductPageComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [EditProductPageComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(EditProductPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
