export const LAST_SAMPLE = 100;
export const TARGET = "signal/cursor";
export const MOVE = "cursor.move";

function sample(value) {
  if (!Number.isInteger(value) || value < 0 || value > LAST_SAMPLE)
    throw new Error("Enter a whole sample from 0 to 100.");
  return value;
}

export class Cursor {
  constructor() {
    this.position = 25;
    this.revision = 0;
    this.draft = null;
    this.history = [];
  }

  preview(value) {
    this.draft = sample(value);
  }

  cancel() {
    this.draft = null;
  }

  commit() {
    if (this.draft === null || this.draft === this.position)
      throw new Error("Choose a different sample first.");
    const record = JSON.stringify({
      version: 1, operation: MOVE, target: TARGET,
      revision: this.revision, from: this.position, to: this.draft
    });
    this.apply(record);
    return record;
  }

  apply(record) {
    const command = JSON.parse(record);
    if (command?.version !== 1 || command.operation !== MOVE || command.target !== TARGET)
      throw new Error("Unrecognized cursor command.");
    sample(command.from);
    sample(command.to);
    if (command.revision !== this.revision || command.from !== this.position)
      throw new Error("Stale target. Cursor and undo history preserved.");
    if (command.from === command.to) throw new Error("Empty cursor move.");
    this.history.push(this.position);
    this.position = command.to;
    this.revision++;
    this.cancel();
  }

  undo() {
    if (!this.history.length) throw new Error("No committed move to undo.");
    this.position = this.history.pop();
    this.revision++;
    this.cancel();
  }
}
