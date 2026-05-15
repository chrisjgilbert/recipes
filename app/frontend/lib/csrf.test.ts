import axios from "axios";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { syncCsrfToken } from "./csrf";

const setMetaToken = (value: string | null) => {
  document.querySelector('meta[name="csrf-token"]')?.remove();
  if (value !== null) {
    const meta = document.createElement("meta");
    meta.setAttribute("name", "csrf-token");
    meta.setAttribute("content", value);
    document.head.appendChild(meta);
  }
};

describe("syncCsrfToken", () => {
  beforeEach(() => {
    delete axios.defaults.headers.common["X-CSRF-Token"];
  });

  afterEach(() => {
    setMetaToken(null);
  });

  it("sets the axios X-CSRF-Token header from the meta tag", () => {
    setMetaToken("token-abc");

    syncCsrfToken();

    expect(axios.defaults.headers.common["X-CSRF-Token"]).toBe("token-abc");
  });

  it("picks up a rotated token on subsequent calls", () => {
    setMetaToken("token-old");
    syncCsrfToken();

    setMetaToken("token-new");
    syncCsrfToken();

    expect(axios.defaults.headers.common["X-CSRF-Token"]).toBe("token-new");
  });

  it("leaves an existing header untouched when the meta tag is missing", () => {
    axios.defaults.headers.common["X-CSRF-Token"] = "previous";

    syncCsrfToken();

    expect(axios.defaults.headers.common["X-CSRF-Token"]).toBe("previous");
  });
});
