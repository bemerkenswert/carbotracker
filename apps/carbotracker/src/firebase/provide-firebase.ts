import {
  ENVIRONMENT_INITIALIZER,
  EnvironmentProviders,
  InjectionToken,
  Provider,
  makeEnvironmentProviders,
} from '@angular/core';
import { FirebaseApp, FirebaseOptions, initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth } from 'firebase/auth';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';

export const FIREBASE_APP = new InjectionToken<FirebaseApp>('firebase_app');

declare const enum EmulatorFeatureKind {
  AuthFeature = 0,
  FirestoreFeature = 1,
}

export declare interface EmulatorFeature<
  FeatureKind extends EmulatorFeatureKind,
> {
  ɵkind: FeatureKind;
  ɵproviders: Provider[];
}

export declare type AuthFeature =
  EmulatorFeature<EmulatorFeatureKind.AuthFeature>;

export declare type FirestoreFeature =
  EmulatorFeature<EmulatorFeatureKind.FirestoreFeature>;

export declare type EmulatorFeatures = AuthFeature | FirestoreFeature;

function emulatorFeature<FeatureKind extends EmulatorFeatureKind>(
  kind: FeatureKind,
  providers: Provider[],
): EmulatorFeature<FeatureKind> {
  return { ɵkind: kind, ɵproviders: providers };
}

export function provideFirebase(
  options: FirebaseOptions,
  ...features: EmulatorFeatures[]
): EnvironmentProviders {
  return makeEnvironmentProviders([
    {
      provide: ENVIRONMENT_INITIALIZER,
      multi: true,
      useFactory: () => {
        return () => initializeApp(options);
      },
    },
    features.map((feature) => feature.ɵproviders),
  ]);
}

export interface AuthEmulatorOptions {
  host?: string;
  port?: number;
  disableWarning?: boolean;
}


export function withAuthEmulator(
  options: AuthEmulatorOptions,
): EmulatorFeatures {
  const providers = [
    {
      provide: ENVIRONMENT_INITIALIZER,
      multi: true,
      useFactory: () => {
        return async () => {
          const host = options.host ?? 'localhost';
          const port = options.port ?? 9099;
          const url = `http://${host}:${port}`;
          connectAuthEmulator(getAuth(), url, { disableWarnings: options.disableWarning ?? false});
          try {
            const body = await fetch(url).then((response) => response.json());
            if (!body.authEmulator.ready) {
              throw new Error();
            }
          } catch (error) {
            throw new Error('Auth not ready!');
          }
        };
      },
    },
  ];
  return emulatorFeature(EmulatorFeatureKind.AuthFeature, providers);
}

export interface FirestoreEmulatorOptions {
  host?: string;
  port?: number;
}

export function withFirestoreEmulator(
  options: FirestoreEmulatorOptions,
): EmulatorFeatures {
  const providers = [
    {
      provide: ENVIRONMENT_INITIALIZER,
      multi: true,
      useFactory: () => {
        return async () => {
          const host = options.host ?? 'localhost';
          const port = options.port ?? 8080;
          connectFirestoreEmulator(getFirestore(), host, port);
          try {
            const url = `http://${host}:${port}`;
            const body = await fetch(url).then((response) => response.text());
            if (body.trim() !== 'Ok') {
              throw new Error();
            }
          } catch (error) {
            throw new Error('Firestore not ready!');
          }
        };
      },
    },
  ];
  return emulatorFeature(EmulatorFeatureKind.FirestoreFeature, providers);
}
