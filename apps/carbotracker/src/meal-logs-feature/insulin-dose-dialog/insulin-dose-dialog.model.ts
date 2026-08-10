export type InsulinDoseDialogResult =
  | { cancelled: true }
  | { cancelled: false; date: Date; insulin: number; note: string | null };
