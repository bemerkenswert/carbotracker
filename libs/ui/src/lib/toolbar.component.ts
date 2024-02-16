import { NgIf } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'ctui-toolbar',
  standalone: true,
  imports: [NgIf, MatIconModule],
  template: `<div>
      @if (showBackwardNavigation) {
      <mat-icon
        (click)="backwardNavigation.emit()"
        style="margin-right: 0.5rem; cursor: pointer"
        >chevron_left</mat-icon
      >
      }
      <h3>{{ title }}</h3>
      <span style="flex: 1 1 auto"></span>
      <ng-content></ng-content>
    </div>
    @if (subTitle) {
    <h6>{{ subTitle }}</h6>
    }`,
  styles: [
    'div { display: flex; flex-direction: row; align-items: center; } h6 { margin: 0; }',
  ],
})
export class CtuiToolbarComponent {
  @Input({ required: true }) public title!: string;
  @Input() public subTitle: string = '';
  @Input() public showBackwardNavigation = false;
  @Output() public readonly backwardNavigation = new EventEmitter<void>();
}
