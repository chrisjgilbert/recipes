import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it, vi, beforeEach } from "vitest";

const mockPost = vi.hoisted(() => vi.fn());
const mockUseForm = vi.hoisted(() =>
  vi.fn(() => ({
    data: { url: "", image: null as File | null },
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
  mockUseForm.mockReset();
  mockUseForm.mockImplementation((initial: Record<string, unknown>) => ({
    data: { ...initial },
    setData: vi.fn(),
    post: mockPost,
    processing: false,
  }));
  mockPost.mockReset();
  mockToastError.mockReset();

  if (!("createObjectURL" in URL)) {
    Object.assign(URL, {
      createObjectURL: vi.fn(() => "blob:fake"),
      revokeObjectURL: vi.fn(),
    });
  }
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

  it("switches to the photo tab and shows the upload affordance", () => {
    render(<ImportForm importError={null} />);
    fireEvent.click(screen.getByRole("tab", { name: /photo/i }));
    expect(screen.getByLabelText(/recipe photo/i)).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /import from photo/i })
    ).toBeDisabled();
  });

  it("posts to /recipes/import/image with FormData when a photo is submitted", () => {
    const file = new File(["x"], "recipe.jpg", { type: "image/jpeg" });
    mockUseForm.mockImplementation((initial: Record<string, unknown>) => {
      if ("image" in initial) {
        return {
          data: { image: file },
          setData: vi.fn(),
          post: mockPost,
          processing: false,
        };
      }
      return {
        data: { ...initial },
        setData: vi.fn(),
        post: mockPost,
        processing: false,
      };
    });

    render(<ImportForm importError={null} />);
    fireEvent.click(screen.getByRole("tab", { name: /photo/i }));
    fireEvent.submit(
      screen.getByRole("button", { name: /import from photo/i }).closest("form")!
    );

    expect(mockPost).toHaveBeenCalledWith(
      "/recipes/import/image",
      expect.objectContaining({ forceFormData: true })
    );
  });

  it("fires toast.error for image_failed on mount", () => {
    render(<ImportForm importError="image_failed" />);
    expect(mockToastError).toHaveBeenCalledWith(
      expect.stringMatching(/photo/i)
    );
  });
});
