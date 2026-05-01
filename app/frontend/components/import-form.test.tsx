import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it, vi, beforeEach } from "vitest";

const mockPost = vi.hoisted(() => vi.fn());
const mockUseForm = vi.hoisted(() =>
  vi.fn(() => ({
    data: { url: "" },
    setData: vi.fn(),
    post: mockPost,
    processing: false,
  }))
);
const mockToastError = vi.hoisted(() => vi.fn());

vi.mock("@inertiajs/react", () => ({ useForm: mockUseForm }));
vi.mock("sonner", () => ({ toast: { error: mockToastError } }));

import { ImportForm } from "./import-form";

beforeEach(() => {
  mockUseForm.mockReturnValue({
    data: { url: "" },
    setData: vi.fn(),
    post: mockPost,
    processing: false,
  });
});

describe("ImportForm", () => {
  it("renders URL input and Import button", () => {
    render(<ImportForm importError={null} />);
    expect(screen.getByLabelText(/recipe url/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /^import$/i })).toBeInTheDocument();
  });

  it("disables Import button when URL is empty", () => {
    render(<ImportForm importError={null} />);
    expect(screen.getByRole("button", { name: /^import$/i })).toBeDisabled();
  });

  it("enables Import button when URL is provided", () => {
    mockUseForm.mockReturnValue({
      data: { url: "https://example.com/recipe" },
      setData: vi.fn(),
      post: mockPost,
      processing: false,
    });
    render(<ImportForm importError={null} />);
    expect(screen.getByRole("button", { name: /^import$/i })).not.toBeDisabled();
  });

  it("shows not_a_recipe warning banner with manual link", () => {
    render(<ImportForm importError="not_a_recipe" />);
    expect(screen.getByText(/doesn't look like a recipe/i)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /add manually/i })).toHaveAttribute(
      "href",
      "/recipes/new?manual=1"
    );
  });

  it("fires toast.error for fetch_failed on mount", () => {
    render(<ImportForm importError="fetch_failed" />);
    expect(mockToastError).toHaveBeenCalledWith(
      expect.stringMatching(/failed to fetch/i)
    );
  });

  it("shows processing state while submitting", () => {
    mockUseForm.mockReturnValue({
      data: { url: "https://example.com/recipe" },
      setData: vi.fn(),
      post: mockPost,
      processing: true,
    });
    render(<ImportForm importError={null} />);
    expect(screen.getByRole("button", { name: /fetching/i })).toBeDisabled();
    expect(screen.getByText(/usually takes/i)).toBeInTheDocument();
  });

  it("calls form.post on submit", () => {
    mockUseForm.mockReturnValue({
      data: { url: "https://example.com/recipe" },
      setData: vi.fn(),
      post: mockPost,
      processing: false,
    });
    render(<ImportForm importError={null} />);
    fireEvent.submit(screen.getByRole("button", { name: /^import$/i }).closest("form")!);
    expect(mockPost).toHaveBeenCalledWith("/recipes/import", expect.any(Object));
  });
});
