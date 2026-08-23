export interface SportDialogData {
  /** Default day for the date field; time always defaults to now. */
  defaultDate?: Date;
}

export type BasalReductionMode = 'none' | 'rate' | 'percent';

export type ConfirmedSportDialogResult = {
  cancelled: false;
  date: Date;
  duration: number;
  sportName: string;
  /** Whether a free-text sport name should be saved into the catalog. */
  saveToCatalog: boolean;
  basalRate: number | null;
  basalReductionPercent: number | null;
  note: string | null;
};

export type SportDialogResult =
  | { cancelled: true }
  | ConfirmedSportDialogResult;
