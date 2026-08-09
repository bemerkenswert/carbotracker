export interface SavedMealNameDialogData {
  title: string;
}

export type SavedMealNameDialogResult =
  | { cancelled: true }
  | { cancelled: false; name: string };
