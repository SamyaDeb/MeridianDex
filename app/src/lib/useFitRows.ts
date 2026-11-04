"use client";
import { useEffect, useState } from "react";

/**
 * Rows of `rowPx` that fit in `heightPx` once `reservePx` (e.g. a ladder's spread row) is taken, split over `groups`
 * (2 for a book's asks + bids), so a fixed-height panel never scrolls. At least 1 per group.
 */
export function fitRows(heightPx: number, rowPx: number, reservePx = 0, groups = 1): number {
  if (!(rowPx > 0) || !(heightPx > 0)) return 1;
  return Math.max(1, Math.floor((heightPx - reservePx) / rowPx / groups));
}

/**
 * Measures the element given to `measure` (a callback ref) and returns `fitRows` for it, re-measured on resize. Undefined until measured
 * (and without ResizeObserver), so callers fall back to their default count. A touch screen's rows are taller
 * (pointer-coarse:h-11): the first `li` inside is measured when there is one, `rowPx` otherwise.
 */
export function useFitRows(rowPx: number, reservePx = 0, groups = 1) {
  // a callback ref: lists mount only once their data loads, after the first render
  const [el, measure] = useState<HTMLElement | null>(null);
  const [rows, setRows] = useState<number>();
  useEffect(() => {
    if (!el || typeof ResizeObserver === "undefined") return;
    const ro = new ResizeObserver(([e]) => {
      const px = el.querySelector("li")?.getBoundingClientRect().height || rowPx;
      setRows(fitRows(e?.contentRect.height ?? 0, px, reservePx, groups));
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, [el, rowPx, reservePx, groups]);
  return { measure, rows };
}
