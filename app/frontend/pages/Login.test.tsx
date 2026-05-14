import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi, beforeEach } from "vitest";

const mockToastError = vi.hoisted(() => vi.fn());
const mockUsePage = vi.hoisted(() => vi.fn());
const mockUseForm = vi.hoisted(() => vi.fn());
const mockPost = vi.hoisted(() => vi.fn());

vi.mock("sonner", () => ({ toast: { error: mockToastError } }));
vi.mock("@inertiajs/react", () => ({
  router: { delete: vi.fn() },
  useForm: mockUseForm,
  usePage: mockUsePage,
}));

import Login from "./Login";

function defaultForm(overrides = {}) {
  return {
    data: { password: "" },
    setData: vi.fn(),
    post: mockPost,
    processing: false,
    ...overrides,
  };
}

function defaultPage(overrides = {}) {
  return {
    props: {
      errors: {},
      flash: { notice: null, alert: null },
      ...overrides,
    },
  };
}

beforeEach(() => {
  mockUseForm.mockReturnValue(defaultForm());
  mockUsePage.mockReturnValue(defaultPage());
});

describe("Login", () => {
  it("renders password field and sign-in button", () => {
    render(<Login />);
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /sign in/i })).toBeInTheDocument();
  });

  it("disables sign-in button when password is empty", () => {
    render(<Login />);
    expect(screen.getByRole("button", { name: /sign in/i })).toBeDisabled();
  });

  it("enables sign-in button when password has a value", () => {
    mockUseForm.mockReturnValue(defaultForm({ data: { password: "secret" } }));
    render(<Login />);
    expect(screen.getByRole("button", { name: /sign in/i })).not.toBeDisabled();
  });

  it("shows error toast when errors.password is set", () => {
    mockUsePage.mockReturnValue(defaultPage({ errors: { password: "Incorrect password" } }));
    render(<Login />);
    expect(mockToastError).toHaveBeenCalledWith("Incorrect password");
  });

  it("shows error toast when flash.alert is set", () => {
    mockUsePage.mockReturnValue(defaultPage({ flash: { notice: null, alert: "Session expired" } }));
    render(<Login />);
    expect(mockToastError).toHaveBeenCalledWith("Session expired");
  });

  it("shows signing-in state while processing", () => {
    mockUseForm.mockReturnValue(defaultForm({ data: { password: "secret" }, processing: true }));
    render(<Login />);
    expect(screen.getByRole("button", { name: /signing in/i })).toBeDisabled();
  });

  it("renders the Recipes heading", () => {
    render(<Login />);
    expect(screen.getByText("Recipes")).toBeInTheDocument();
  });
});
