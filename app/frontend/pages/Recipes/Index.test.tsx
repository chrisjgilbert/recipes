import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi, beforeEach } from "vitest";

const mockRouterGet = vi.hoisted(() => vi.fn());
const mockToastSuccess = vi.hoisted(() => vi.fn());
const mockToastError = vi.hoisted(() => vi.fn());

vi.mock("sonner", () => ({ toast: { success: mockToastSuccess, error: mockToastError } }));
vi.mock("@inertiajs/react", () => ({
  Link: ({ children, href }: { children: React.ReactNode; href: string }) => (
    <a href={href}>{children}</a>
  ),
  router: { get: mockRouterGet },
}));
vi.mock("@/components/nav-bar", () => ({ NavBar: () => <nav>NavBar</nav> }));

import RecipesIndex from "./Index";
import type { RecipeSummary } from "@/lib/types";

const baseRecipe: RecipeSummary = {
  id: "r1",
  title: "Pasta",
  image_url: null,
  total_time_minutes: 30,
  servings: 2,
  tags: ["quick"],
  cuisine: "Italian",
  course: "Main",
  created_at: "2026-01-01T00:00:00Z",
};

const defaultFilters = { q: "", cuisine: "", course: "", sort: "created_at" as const, order: "desc" as const };
const defaultFlash = { notice: null, alert: null };

beforeEach(() => {
  mockRouterGet.mockReset();
  mockToastSuccess.mockReset();
  mockToastError.mockReset();
});

describe("RecipesIndex", () => {
  it("shows the recipe count", () => {
    render(
      <RecipesIndex
        items={[baseRecipe]}
        total={1}
        limit={24}
        offset={0}
        filters={defaultFilters}
        flash={defaultFlash}
      />
    );
    expect(screen.getByText("1 recipe")).toBeInTheDocument();
  });

  it("uses plural form for multiple recipes", () => {
    render(
      <RecipesIndex
        items={[baseRecipe, { ...baseRecipe, id: "r2", title: "Pizza" }]}
        total={2}
        limit={24}
        offset={0}
        filters={defaultFilters}
        flash={defaultFlash}
      />
    );
    expect(screen.getByText("2 recipes")).toBeInTheDocument();
  });

  it("shows empty state CTA when there are no recipes", () => {
    render(
      <RecipesIndex
        items={[]}
        total={0}
        limit={24}
        offset={0}
        filters={defaultFilters}
        flash={defaultFlash}
      />
    );
    expect(screen.getByRole("link", { name: /add your first recipe/i })).toBeInTheDocument();
  });

  it("shows Load more button when more recipes are available", () => {
    render(
      <RecipesIndex
        items={[baseRecipe]}
        total={5}
        limit={1}
        offset={0}
        filters={defaultFilters}
        flash={defaultFlash}
      />
    );
    expect(screen.getByRole("button", { name: /load more/i })).toBeInTheDocument();
  });

  it("hides Load more button when all recipes are loaded", () => {
    render(
      <RecipesIndex
        items={[baseRecipe]}
        total={1}
        limit={24}
        offset={0}
        filters={defaultFilters}
        flash={defaultFlash}
      />
    );
    expect(screen.queryByRole("button", { name: /load more/i })).not.toBeInTheDocument();
  });

  it("calls router.get with next offset when Load more is clicked", () => {
    render(
      <RecipesIndex
        items={[baseRecipe]}
        total={5}
        limit={1}
        offset={0}
        filters={defaultFilters}
        flash={defaultFlash}
      />
    );
    fireEvent.click(screen.getByRole("button", { name: /load more/i }));
    expect(mockRouterGet).toHaveBeenCalledWith(
      "/",
      expect.objectContaining({ offset: 1 }),
      expect.any(Object)
    );
  });

  it("shows toast.success on flash.notice", () => {
    render(
      <RecipesIndex
        items={[]}
        total={0}
        limit={24}
        offset={0}
        filters={defaultFilters}
        flash={{ notice: "Recipe deleted", alert: null }}
      />
    );
    expect(mockToastSuccess).toHaveBeenCalledWith("Recipe deleted");
  });

  it("shows toast.error on flash.alert", () => {
    render(
      <RecipesIndex
        items={[]}
        total={0}
        limit={24}
        offset={0}
        filters={defaultFilters}
        flash={{ notice: null, alert: "Something went wrong" }}
      />
    );
    expect(mockToastError).toHaveBeenCalledWith("Something went wrong");
  });
});
