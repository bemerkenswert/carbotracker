import { NavigationEnd } from '@angular/router';
import { routerNavigatedAction } from '@ngrx/router-store';
import { Subject } from 'rxjs';
import { LoginApiActions, LogoutApiActions } from '../actions/api.actions';
import { reloadApp$ } from './routing.effects';

const createNavigationEndedAction = () =>
  routerNavigatedAction({
    payload: {
      event: new NavigationEnd(1, '/app/settings', '/login'),
      routerState: {} as never,
    },
  });

describe('reloadApp$', () => {
  it('reloads after logout navigation completes', () => {
    const actions$ = new Subject();
    const reload = jest.fn();
    const document = {
      location: {
        reload,
      },
    } as unknown as Document;

    reloadApp$(actions$ as never, document).subscribe();

    actions$.next(LogoutApiActions.logoutSuccessful());

    expect(reload).not.toHaveBeenCalled();

    actions$.next(createNavigationEndedAction());

    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('reloads after login navigation completes', () => {
    const actions$ = new Subject();
    const reload = jest.fn();
    const document = {
      location: {
        reload,
      },
    } as unknown as Document;

    reloadApp$(actions$ as never, document).subscribe();

    actions$.next(LoginApiActions.loginSuccessful({ userCredential: {} as never }));

    expect(reload).not.toHaveBeenCalled();

    actions$.next(createNavigationEndedAction());

    expect(reload).toHaveBeenCalledTimes(1);
  });
});
