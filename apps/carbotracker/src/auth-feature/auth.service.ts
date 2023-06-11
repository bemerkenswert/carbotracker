import { Injectable, inject } from "@angular/core";
import { FirebaseService } from "../app/firebase.service";
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';

@Injectable({ providedIn: 'root'})
export class AuthService {
    private readonly fireBaseService = inject(FirebaseService);
    private readonly auth = getAuth();
    

    public login() {
        
       signInWithEmailAndPassword(this.auth, 'steffenlm@outlook.com', 'Josef_07!' ).then((val) => {
        debugger;

       }).catch((val) => {
        debugger;
       });
    }

}