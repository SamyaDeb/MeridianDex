import { describe, expect, it } from "vitest";
import { fitRows } from "./useFitRows";

describe("fitRows: only the rows that fit a fixed-height panel", () => {
  it("whole rows only, never a cut-off one", () => {
    expect(fitRows(600, 25)).toBe(24);
    expect(fitRows(624, 25)).toBe(24);
    expect(fitRows(625, 25)).toBe(25);
  });
  it("a book: the spread row is reserved, the rest split between asks and bids", () => {
    expect(fitRows(625, 25, 25, 2)).toBe(12);
    expect(fitRows(500, 24, 30, 2)).toBe(9);
  });
  it("at least one row, even in a panel too small or not laid out yet", () => {
    expect(fitRows(10, 25)).toBe(1);
    expect(fitRows(0, 25)).toBe(1);
    expect(fitRows(100, 0)).toBe(1);
  });
});
