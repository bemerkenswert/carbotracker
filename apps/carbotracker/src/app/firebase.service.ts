import { Injectable } from '@angular/core';
import { FirebaseApp, initializeApp } from 'firebase/app';

@Injectable({ providedIn: 'root' })
export class FirebaseService {
  private readonly firebaseApp: FirebaseApp;

  constructor() {
    this.firebaseApp = this.initFireBase();
  }

  private initFireBase() {
    const firebaseConfig = {
      apiKey: 'AIzaSyBh6fpP_cO3C3bR-fzHR8WqHhPMURhvHqQ',
      authDomain: 'carbotracker.firebaseapp.com',
      projectId: 'carbotracker',
      storageBucket: 'carbotracker.appspot.com',
      messagingSenderId: '909622893544',
      appId: '1:909622893544:web:8f64f0bd468a035e33e25d',
      measurementId: 'G-MKN5SN9M5D',
    };
    return initializeApp(firebaseConfig);
  }
}
