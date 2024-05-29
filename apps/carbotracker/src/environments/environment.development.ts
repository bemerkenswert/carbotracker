import {
  provideFirebase,
  withAuthEmulator,
  withFirestoreEmulator,
} from '../firebase/provide-firebase';

export const environment = {
  fireBaseProvider: () =>
    provideFirebase(
      {
        apiKey: 'AIzaSyBh6fpP_cO3C3bR-fzHR8WqHhPMURhvHqQ',
        authDomain: 'carbotracker.firebaseapp.com',
        projectId: 'carbotracker',
        storageBucket: 'carbotracker.appspot.com',
        messagingSenderId: '909622893544',
        appId: '1:909622893544:web:8f64f0bd468a035e33e25d',
        measurementId: 'G-MKN5SN9M5D',
      },
      withAuthEmulator({ disableWarning: true }),
      withFirestoreEmulator({}),
    ),
};
