import { Injectable } from '@angular/core';
import { getAnalytics } from 'firebase/analytics';
import { initializeApp } from 'firebase/app';

@Injectable({ providedIn: 'root' })
export class FireStore {
  constructor() {
    this.initFireBase();
  }

  private initFireBase() {
    // TODO: Add SDKs for Firebase products that you want to use
    // https://firebase.google.com/docs/web/setup#available-libraries

    // Your web app's Firebase configuration
    // For Firebase JS SDK v7.20.0 and later, measurementId is optional
    const firebaseConfig = {
      apiKey: 'AIzaSyBh6fpP_cO3C3bR-fzHR8WqHhPMURhvHqQ',
      authDomain: 'carbotracker.firebaseapp.com',
      projectId: 'carbotracker',
      storageBucket: 'carbotracker.appspot.com',
      messagingSenderId: '909622893544',
      appId: '1:909622893544:web:8f64f0bd468a035e33e25d',
      measurementId: 'G-MKN5SN9M5D',
    };

    // Initialize Firebase
    const app = initializeApp(firebaseConfig);
    getAnalytics(app);
  }
}
