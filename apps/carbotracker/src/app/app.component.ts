import { Component, inject } from '@angular/core';
import { FireStore } from './firestore.service';

// Import the functions you need from the SDKs you need

@Component({
  standalone: true,
  imports: [],
  selector: 'carbotracker-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss'],
})
export class AppComponent {
  title = 'carbotracker';
  fireStore = inject(FireStore);
}
