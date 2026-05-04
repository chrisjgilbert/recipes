import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { RecipeSummary } from "@/lib/types";

vi.mock("@inertiajs/react", () => ({
  Link: ({ children, href }: { children: React.ReactNode; href: string }) => (
    <a href={href}>{children}</a>
  ),
}));

import { RecipeCard } from "./recipe-card";

const base: RecipeSummary = {
  id: "rec_1",
  title: "Spicy Ramen",
  chef: "Ivan Orkin",
  image_url: null,
  total_time_minutes: 45,
  servings: 2,
  created_at: "2026-01-01T00:00:00Z",
};

describe("RecipeCard", () => {
  it("links to the recipe detail page", () => {
    render(<RecipeCard recipe={base} />);
    expect(screen.getByRole("link")).toHaveAttribute("href", "/recipes/rec_1");
  });

  it("renders title, chef, formatted time and servings", () => {
    render(<RecipeCard recipe={base} />);
    expect(screen.getByText("Spicy Ramen")).toBeInTheDocument();
    expect(screen.getByText("Ivan Orkin")).toBeInTheDocument();
    expect(screen.getByText("45 min")).toBeInTheDocument();
    expect(screen.getByText("2")).toBeInTheDocument();
  });

  it("shows image or placeholder", () => {
    const { rerender } = render(<RecipeCard recipe={base} />);
    expect(screen.getByText("No image")).toBeInTheDocument();
    rerender(
      <RecipeCard recipe={{ ...base, image_url: "https://example.com/a.jpg" }} />,
    );
    const img = screen.getByRole("img") as HTMLImageElement;
    expect(img.src).toBe("https://example.com/a.jpg");
  });
});
