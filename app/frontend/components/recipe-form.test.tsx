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

  it("shows Saving… and disables submit when submitting=true", () => {
    render(<RecipeForm submitLabel="Create recipe" onSubmit={vi.fn()} submitting />);
    const btn = screen.getByRole("button", { name: /saving/i });
    expect(btn).toBeDisabled();
  });

  it("pre-fills title and chef from defaultValues", () => {
    render(
      <RecipeForm
        defaultValues={{ title: "Existing Recipe", chef: "Yotam Ottolenghi" }}
        submitLabel="Save"
        onSubmit={vi.fn()}
      />
    );
    expect(screen.getByLabelText(/title/i)).toHaveValue("Existing Recipe");
    expect(screen.getByLabelText(/chef/i)).toHaveValue("Yotam Ottolenghi");
  });

  it("keeps raw ingredient values in the form when canonical values are also present", () => {
    render(
      <RecipeForm
        defaultValues={{
          title: "Existing Recipe",
          parts: [
            {
              name: "",
              ingredients: [
                {
                  quantity: "1",
                  unit: "cup",
                  canonical_quantity: "240",
                  canonical_unit: "ml",
                  name: "stock",
                  notes: null,
                },
              ],
              instructions: [{ step: 1, text: "Warm the stock." }],
            },
          ],
        }}
        submitLabel="Save"
        onSubmit={vi.fn()}
      />
    );

    expect(screen.getByPlaceholderText("Qty")).toHaveValue("1");
    expect(screen.getByPlaceholderText("Unit")).toHaveValue("cup");
  });

  it("adds a second part when clicking Add part", () => {
    render(<RecipeForm submitLabel="Save" onSubmit={vi.fn()} />);
    fireEvent.click(screen.getAllByRole("button", { name: /add part/i })[0]);
    expect(screen.getAllByRole("button", { name: /remove part/i })).toHaveLength(2);
  });

  it("removes a part when clicking its remove button", () => {
    render(<RecipeForm submitLabel="Save" onSubmit={vi.fn()} />);
    fireEvent.click(screen.getAllByRole("button", { name: /add part/i })[0]);
    const removeBtns = screen.getAllByRole("button", { name: /remove part/i });
    expect(removeBtns).toHaveLength(2);
    fireEvent.click(removeBtns[0]);
    expect(screen.getAllByRole("button", { name: /remove part/i })).toHaveLength(1);
  });

  it("shows a 'Parts' section heading so users discover the parts feature", () => {
    render(<RecipeForm submitLabel="Save" onSubmit={vi.fn()} />);
    expect(
      screen.getByRole("heading", { name: /^parts$/i })
    ).toBeInTheDocument();
  });

  it("labels each part with its number so the structure is visible even with one part", () => {
    render(<RecipeForm submitLabel="Save" onSubmit={vi.fn()} />);
    expect(screen.getByText(/part 1/i)).toBeInTheDocument();
    fireEvent.click(screen.getAllByRole("button", { name: /add part/i })[0]);
    expect(screen.getByText(/part 2/i)).toBeInTheDocument();
  });

  it("shows an 'Add part' button at the bottom of the parts list as well", () => {
    render(<RecipeForm submitLabel="Save" onSubmit={vi.fn()} />);
    // Two add-part buttons — one near the heading, one at the bottom of the list
    expect(screen.getAllByRole("button", { name: /add part/i })).toHaveLength(2);
  });
});
