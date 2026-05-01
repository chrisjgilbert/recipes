import { test, expect } from "@playwright/test";

async function login(page: import("@playwright/test").Page) {
  await page.goto("/login");
  await page.getByLabel("Password").fill("e2e-secret");
  await page.getByRole("button", { name: /sign in/i }).click();
  await expect(page).toHaveURL("/");
}

test("login -> import -> list -> delete", async ({ page }) => {
  await login(page);

  // Empty state
  await expect(page.getByText(/no recipes yet/i)).toBeVisible();

  // Import from /recipes/new
  await page.goto("/recipes/new");
  await page.getByLabel("Recipe URL").fill("https://example.com/pasta");
  await page.getByRole("button", { name: /^import$/i }).click();

  // Lands on the detail page with the extracted title
  await expect(page.getByRole("heading", { name: /Playwright Pasta/ })).toBeVisible({
    timeout: 30_000,
  });

  // Go home: the recipe shows in the grid
  await page.goto("/");
  await expect(
    page.getByRole("link", { name: /Playwright Pasta/ }).first(),
  ).toBeVisible();
  await expect(page.getByText("1 recipe")).toBeVisible();

  // Click into it and delete
  await page.getByRole("link", { name: /Playwright Pasta/ }).first().click();
  await page.getByRole("button", { name: /delete/i }).click();
  await page
    .getByRole("alertdialog")
    .getByRole("button", { name: /delete/i })
    .click();

  await expect(page).toHaveURL("/");
  await expect(page.getByText(/no recipes yet/i)).toBeVisible();
});

test("manual recipe creation", async ({ page }) => {
  await login(page);

  await page.goto("/recipes/new?manual=1");
  await page.getByLabel(/title/i).fill("Hand-Crafted Stew");
  await page.getByRole("button", { name: /create recipe/i }).click();

  await expect(page.getByRole("heading", { name: "Hand-Crafted Stew" })).toBeVisible();

  // Clean up
  await page.getByRole("button", { name: /delete/i }).click();
  await page.getByRole("alertdialog").getByRole("button", { name: /delete/i }).click();
  await expect(page).toHaveURL("/");
});

test("edit recipe title", async ({ page }) => {
  await login(page);

  // Create a recipe via import
  await page.goto("/recipes/new");
  await page.getByLabel("Recipe URL").fill("https://example.com/pasta");
  await page.getByRole("button", { name: /^import$/i }).click();
  await expect(page.getByRole("heading", { name: /Playwright Pasta/ })).toBeVisible({
    timeout: 30_000,
  });

  // Edit it
  await page.getByRole("link", { name: /edit/i }).click();
  const titleInput = page.getByLabel(/title/i);
  await titleInput.clear();
  await titleInput.fill("Updated Pasta");
  await page.getByRole("button", { name: /save changes/i }).click();

  await expect(page.getByRole("heading", { name: "Updated Pasta" })).toBeVisible();

  // Clean up
  await page.getByRole("button", { name: /delete/i }).click();
  await page.getByRole("alertdialog").getByRole("button", { name: /delete/i }).click();
  await expect(page).toHaveURL("/");
});

test("search filters the recipe list", async ({ page }) => {
  await login(page);

  // Create a recipe via import (fake gives us "Playwright Pasta")
  await page.goto("/recipes/new");
  await page.getByLabel("Recipe URL").fill("https://example.com/pasta");
  await page.getByRole("button", { name: /^import$/i }).click();
  await expect(page.getByRole("heading", { name: /Playwright Pasta/ })).toBeVisible({
    timeout: 30_000,
  });

  await page.goto("/");
  await expect(page.getByText("1 recipe")).toBeVisible();

  // Search that matches
  await page.getByPlaceholder(/search title or ingredient/i).fill("Playwright");
  await expect(page.getByText("1 recipe")).toBeVisible();

  // Search that doesn't match
  await page.getByPlaceholder(/search title or ingredient/i).fill("xyzimpossible");
  await expect(page.getByText("0 recipes")).toBeVisible();

  // Clear search restores the list
  await page.getByPlaceholder(/search title or ingredient/i).fill("");
  await expect(page.getByText("1 recipe")).toBeVisible();

  // Clean up
  await page.getByRole("link", { name: /Playwright Pasta/ }).first().click();
  await page.getByRole("button", { name: /delete/i }).click();
  await page.getByRole("alertdialog").getByRole("button", { name: /delete/i }).click();
  await expect(page).toHaveURL("/");
});
