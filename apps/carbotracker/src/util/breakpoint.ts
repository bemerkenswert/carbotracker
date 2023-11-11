import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';
import { inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { map, shareReplay } from 'rxjs';

export const isHandset = () =>
  toSignal(
    inject(BreakpointObserver)
      .observe(Breakpoints.Handset)
      .pipe(
        map((result) => result.matches),
        shareReplay(),
      ),
  );
