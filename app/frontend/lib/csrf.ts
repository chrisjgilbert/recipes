import axios from "axios";

// Rails rotates the authenticity token when the session changes (e.g. after
// logout). Re-read it from the meta tag so axios sends the current token.
export const syncCsrfToken = () => {
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;
  if (token) {
    axios.defaults.headers.common["X-CSRF-Token"] = token;
  }
};
