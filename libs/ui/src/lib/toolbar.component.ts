import { NgIf } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { MatToolbarModule } from '@angular/material/toolbar';

@Component({
  selector: 'ctui-toolbar',
  standalone: true,
  imports: [NgIf, MatIconModule, MatToolbarModule],
  template: `<mat-toolbar>
    @if (showBackwardNavigation) {
    <mat-icon
      (click)="backwardNavigation.emit()"
      style="margin-right: 0.5rem; cursor: pointer"
      >chevron_left</mat-icon
    >
    }
    <span>{{ title }}</span>
    <span style="flex: 1 1 auto"></span>
    <ng-content></ng-content>
  </mat-toolbar>`,
  styles: [],
})
export class CtuiToolbarComponent {
  @Input({ required: true }) public title!: string;
  @Input() public showBackwardNavigation = false;
  @Output() public readonly backwardNavigation = new EventEmitter<void>();
}
