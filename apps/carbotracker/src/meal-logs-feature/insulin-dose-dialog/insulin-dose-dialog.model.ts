export interface InsulinDoseDialogData {
  /** When set, the dialog pre-fills its fields and titles itself "Edit". */
  dose?: {
    createdAt: Date;
    insulin: number;
    note: string | null;
  };
}

export type ConfirmedInsulinDoseDialogResult = {
  cancelled: false;
  date: Date;
  insulin: number;
  note: string | null;
};

export type InsulinDoseDialogResult =
  | { cancelled: true }
  | ConfirmedInsulinDoseDialogResult;
