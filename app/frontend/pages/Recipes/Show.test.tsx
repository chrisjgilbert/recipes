import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi, beforeEach } from "vitest";

const mockRouterDelete = vi.hoisted(() => vi.fn());

vi.mock("@inertiajs/react", () => ({
  Link: ({ children, href }: { children: React.ReactNode; href: string }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: mockRouterDelete },
}));
vi.mock("@/components/nav-bar", () => ({ NavBar: () => <nav>NavBar</nav> }));

import RecipesShow from "./Show";
import type { Recipe } from "@/lib/types";

const baseRecipe: Recipe = {
  id: "r1",
  title: "Spicy Ramen",
  source_url: "https://example.com/ramen",
  source_site: "example.com",
  description: "A warming bowl",
  image_url: null,
  prep_time_minutes: 10,
  cook_time_minutes: 20,
  total_time_minutes: 30,
  servings: 2,
  cuisine: "Japanese",
  course: "Main",
  difficulty: "easy",
  tags: ["spicy", "noodles"],
  notes: "Add chilli to taste",
  parts: [
    {
      name: "",
      ingredients: [{ quantity: "200", unit: "g", name: "noodles", notes: null }],
      instructions: [{ step: 1, text: "Boil the noodles." }],
    },
  ],
  created_at: "2026-01-01T00:00:00Z",
  updated_at: "2026-01-01T00:00:00Z",
};

beforeEach(() => {
  mockRouterDelete.mockReset();
});

describe("RecipesShow", () => {
  it("renders title and description", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    expect(screen.getByRole("heading", { name: "Spicy Ramen" })).toBeInTheDocument();
    expect(screen.getByText("A warming bowl")).toBeInTheDocument();
  });

  it("renders time metadata and servings", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    expect(screen.getByText(/total 30 min/i)).toBeInTheDocument();
    expect(screen.getByText(/prep 10 min/i)).toBeInTheDocument();
    expect(screen.getByText(/cook 20 min/i)).toBeInTheDocument();
    expect(screen.getByText(/serves 2/i)).toBeInTheDocument();
  });

  it("renders tags as badges", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    expect(screen.getByText("spicy")).toBeInTheDocument();
    expect(screen.getByText("noodles")).toBeInTheDocument();
  });

  it("renders ingredients and instructions", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    expect(screen.getByText("noodles")).toBeInTheDocument();
    expect(screen.getByText("Boil the noodles.")).toBeInTheDocument();
  });

  it("renders notes section", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    expect(screen.getByText("Add chilli to taste")).toBeInTheDocument();
  });

  it("renders source link", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    expect(screen.getByRole("link", { name: /example\.com/i })).toHaveAttribute(
      "href",
      "https://example.com/ramen"
    );
  });

  it("renders Edit link pointing to the edit route", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    expect(screen.getByRole("link", { name: /edit/i })).toHaveAttribute(
      "href",
      "/recipes/r1/edit"
    );
  });

  it("opens delete confirmation dialog on Delete button click", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    fireEvent.click(screen.getByRole("button", { name: /delete/i }));
    expect(screen.getByRole("alertdialog")).toBeInTheDocument();
    expect(screen.getByText(/delete this recipe/i)).toBeInTheDocument();
  });

  it("calls router.delete when Delete is confirmed", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    fireEvent.click(screen.getByRole("button", { name: /delete/i }));
    fireEvent.click(within(screen.getByRole("alertdialog")).getByRole("button", { name: /delete/i }));
    expect(mockRouterDelete).toHaveBeenCalledWith("/recipes/r1");
  });

  it("does not call router.delete when Cancel is clicked", () => {
    render(<RecipesShow recipe={baseRecipe} />);
    fireEvent.click(screen.getByRole("button", { name: /delete/i }));
    fireEvent.click(screen.getByRole("button", { name: /cancel/i }));
    expect(mockRouterDelete).not.toHaveBeenCalled();
  });
});
