import { filter, pipe } from 'rxjs';

export const filterNull = <T>() =>
  pipe(filter((value: T | null): value is T => Boolean(value)));
