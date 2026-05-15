import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { RecipeFilters } from "./recipe-filters";

const baseValue = {
  q: "",
  sort: "created_at" as const,
  order: "desc" as const,
};

describe("RecipeFilters", () => {
  it("debounces search ~300ms after last keystroke", async () => {
    const onChange = vi.fn();
    render(<RecipeFilters value={baseValue} onChange={onChange} />);
    fireEvent.change(screen.getByPlaceholderText(/search recipes/i), {
      target: { value: "pasta" },
    });
    expect(onChange).not.toHaveBeenCalled();
    await waitFor(
      () => expect(onChange).toHaveBeenCalledWith({ ...baseValue, q: "pasta" }),
      { timeout: 1000 },
    );
  });
});
