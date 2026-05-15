const VERSION = "v2";
const SHELL_CACHE = `cookery-shell-${VERSION}`;
const ASSET_CACHE = `cookery-assets-${VERSION}`;
const RECIPE_CACHE = `cookery-recipes-${VERSION}`;
const RECIPE_CACHE_LIMIT = 50;

const SHELL_URLS = ["/", "/manifest.webmanifest"];
// Auth endpoints carry per-session CSRF tokens; never serve them from cache.
const AUTH_PATHS = new Set(["/login", "/logout"]);

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE).then((cache) => cache.addAll(SHELL_URLS)).catch(() => {}),
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(
        names
          .filter((n) => !n.endsWith(VERSION))
          .map((n) => caches.delete(n)),
      ),
    ),
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (AUTH_PATHS.has(url.pathname)) return;

  // Vite assets: cache-first (immutable hashed filenames).
  if (url.pathname.startsWith("/vite/") || url.pathname.startsWith("/vite-dev/")) {
    event.respondWith(cacheFirst(request, ASSET_CACHE));
    return;
  }

  // Recipe detail pages: stale-while-revalidate, with bounded cache.
  if (/^\/recipes\/[^/]+$/.test(url.pathname)) {
    event.respondWith(staleWhileRevalidate(request, RECIPE_CACHE, RECIPE_CACHE_LIMIT));
    return;
  }

  // HTML and Inertia responses: network-first, fall back to cached shell.
  if (request.headers.get("accept")?.includes("text/html") || request.headers.get("x-inertia")) {
    event.respondWith(networkFirst(request, SHELL_CACHE));
    return;
  }
});

async function cacheFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok) cache.put(request, response.clone());
  return response;
}

async function networkFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  try {
    const response = await fetch(request);
    if (response.ok) cache.put(request, response.clone());
    return response;
  } catch {
    const cached = await cache.match(request);
    if (cached) return cached;
    return caches.match("/");
  }
}

async function staleWhileRevalidate(request, cacheName, limit) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  const network = fetch(request)
    .then(async (response) => {
      if (response.ok) {
        await cache.put(request, response.clone());
        await trim(cache, limit);
      }
      return response;
    })
    .catch(() => cached);
  return cached || network;
}

async function trim(cache, limit) {
  const keys = await cache.keys();
  if (keys.length <= limit) return;
  await Promise.all(keys.slice(0, keys.length - limit).map((k) => cache.delete(k)));
}
