import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { RecipeForm } from "./recipe-form";

describe("RecipeForm", () => {
  it("renders title field and submit button", () => {
    render(<RecipeForm submitLabel="Create recipe" onSubmit={vi.fn()} />);
    expect(screen.getByLabelText(/title/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /create recipe/i })).toBeInTheDocument();
  });

  it("auto-appends an empty part on mount", () => {
    render(<RecipeForm submitLabel="Save" onSubmit={vi.fn()} />);
    // Remove-part button only renders when at least one part exists
    expect(screen.getByRole("button", { name: /remove part/i })).toBeInTheDocument();
  });

  it("calls onSubmit with form values on submit", async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<RecipeForm submitLabel="Create recipe" onSubmit={onSubmit} />);

    fireEvent.change(screen.getByLabelText(/title/i), { target: { value: "My Recipe" } });
    fireEvent.click(screen.getByRole("button", { name: /create recipe/i }));

    await waitFor(() =>
      expect(onSubmit).toHaveBeenCalledWith(expect.objectContaining({ title: "My Recipe" }))
    );
  });

  it("parses comma-separated tags string into an array", async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<RecipeForm submitLabel="Save" onSubmit={onSubmit} />);

    fireEvent.change(screen.getByLabelText(/title/i), { target: { value: "T" } });
    fireEvent.change(screen.getByLabelText(/tags/i), { target: { value: "quick, easy, vegan" } });
    fireEvent.click(screen.getByRole("button", { name: /save/i }));

    await waitFor(() =>
      expect(onSubmit).toHaveBeenCalledWith(
        expect.objectContaining({ tags: ["quick", "easy", "vegan"] })
      )
    );
  });

  it("shows Saving… and disables submit when submitting=true", () => {
    render(<RecipeForm submitLabel="Create recipe" onSubmit={vi.fn()} submitting />);
    const btn = screen.getByRole("button", { name: /saving/i });
    expect(btn).toBeDisabled();
  });

  it("pre-fills title from defaultValues", () => {
    render(
      <RecipeForm
        defaultValues={{ title: "Existing Recipe", tags: ["italian", "pasta"] }}
        submitLabel="Save"
        onSubmit={vi.fn()}
      />
    );
    expect(screen.getByLabelText(/title/i)).toHaveValue("Existing Recipe");
    // react-hook-form's register overrides defaultValue with the form state
    // value, so the array is stringified without spaces.
    expect(screen.getByLabelText(/tags/i)).toHaveValue("italian,pasta");
  });

  it("adds a second part when clicking Add part", () => {
    render(<RecipeForm submitLabel="Save" onSubmit={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", { name: /add part/i }));
    expect(screen.getAllByRole("button", { name: /remove part/i })).toHaveLength(2);
  });

  it("removes a part when clicking its remove button", () => {
    render(<RecipeForm submitLabel="Save" onSubmit={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", { name: /add part/i }));
    const removeBtns = screen.getAllByRole("button", { name: /remove part/i });
    expect(removeBtns).toHaveLength(2);
    fireEvent.click(removeBtns[0]);
    expect(screen.getAllByRole("button", { name: /remove part/i })).toHaveLength(1);
  });
});
