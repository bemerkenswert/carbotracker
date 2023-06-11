import { Directive, ElementRef, inject } from '@angular/core';

@Directive({
  selector: '[ctuiFixedPosition]',
  standalone: true,
})
export class CtuiFixedPositionDirective {
  private readonly elementRef = inject(ElementRef);
  constructor() {
    this.elementRef.nativeElement.style.position = 'fixed';
    this.elementRef.nativeElement.style.bottom = '1rem';
    this.elementRef.nativeElement.style.right = '1rem';
  }
}
