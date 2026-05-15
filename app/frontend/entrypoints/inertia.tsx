import "../styles/application.css";

import { createInertiaApp, router } from "@inertiajs/react";
import { createRoot, hydrateRoot } from "react-dom/client";
import { Toaster } from "sonner";

import { syncCsrfToken } from "../lib/csrf";

syncCsrfToken();
router.on("success", syncCsrfToken);

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
