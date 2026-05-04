import "../styles/application.css";

import { createInertiaApp, router } from "@inertiajs/react";
import axios from "axios";
import { createRoot, hydrateRoot } from "react-dom/client";
import { Toaster } from "sonner";

// Rails uses X-CSRF-Token with the authenticity token from the meta tag.
const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;
if (csrfToken) {
  axios.defaults.headers.common["X-CSRF-Token"] = csrfToken;
}

router.on("invalid", (event) => {
  if (event.detail.response.status === 422) {
    event.preventDefault();
  }
});

type PageModule = { default: React.ComponentType<Record<string, unknown>> };

createInertiaApp({
  resolve: (name) => {
    const pages = import.meta.glob<PageModule>(
      ["../pages/**/*.tsx", "!../pages/**/*.test.tsx"],
      { eager: true },
    );
    const page = pages[`../pages/${name}.tsx`];
    if (!page) throw new Error(`Inertia page not found: ${name}`);
    return page;
  },
  setup({ el, App, props }) {
    const app = (
      <>
        <App {...props} />
        <Toaster position="top-right" richColors />
      </>
    );
    if (el.hasChildNodes()) {
      hydrateRoot(el, app);
    } else {
      createRoot(el).render(app);
    }
  },
});

if ("serviceWorker" in navigator && import.meta.env.PROD) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch(() => {});
  });
}
