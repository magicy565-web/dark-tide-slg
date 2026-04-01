// Service Worker for Dark Tide SLG PWA
// Cache version — bump to invalidate all caches on update
const CACHE_VERSION = "dark-tide-v1";
const CACHE_NAME = `dark-tide-slg-${CACHE_VERSION}`;

// Core files that must be cached for the app to run
const PRECACHE_ASSETS = [
	"./",
	"./index.html",
	"./index.js",
	"./index.wasm",
	"./index.pck",
	"./index.worker.js",
	"./index.audio.worklet.js",
	"./offline.html",
];

// Install: precache core files
self.addEventListener("install", (event) => {
	event.waitUntil(
		caches.open(CACHE_NAME).then((cache) => {
			// Use addAll but don't fail install if optional files are missing
			return cache.addAll(PRECACHE_ASSETS).catch((err) => {
				console.warn("[SW] Precache partial failure:", err);
				// At minimum cache the shell
				return cache.add("./index.html");
			});
		})
	);
	// Activate immediately without waiting for old SW to release clients
	self.skipWaiting();
});

// Activate: clean up old caches
self.addEventListener("activate", (event) => {
	event.waitUntil(
		caches.keys().then((cacheNames) => {
			return Promise.all(
				cacheNames
					.filter((name) => name.startsWith("dark-tide-slg-") && name !== CACHE_NAME)
					.map((name) => caches.delete(name))
			);
		})
	);
	// Take control of all open clients immediately
	self.clients.claim();
});

// Fetch: cache-first for assets, network-first for HTML
self.addEventListener("fetch", (event) => {
	const url = new URL(event.request.url);

	// For .pck, .wasm, .js assets: cache-first (they are versioned)
	if (
		url.pathname.endsWith(".pck") ||
		url.pathname.endsWith(".wasm") ||
		url.pathname.endsWith(".js") ||
		url.pathname.endsWith(".png") ||
		url.pathname.endsWith(".webp") ||
		url.pathname.endsWith(".ogv") ||
		url.pathname.endsWith(".otf") ||
		url.pathname.endsWith(".ttf")
	) {
		event.respondWith(
			caches.match(event.request).then((cached) => {
				if (cached) {
					return cached;
				}
				return fetch(event.request).then((response) => {
					if (response && response.status === 200 && response.type === "basic") {
						const cloned = response.clone();
						caches.open(CACHE_NAME).then((cache) => {
							cache.put(event.request, cloned);
						});
					}
					return response;
				});
			})
		);
		return;
	}

	// For navigation / HTML: network-first, fall back to cache
	if (event.request.mode === "navigate") {
		event.respondWith(
			fetch(event.request).catch(() => {
				return caches.match(event.request).then((cached) => {
					return cached || caches.match("./offline.html");
				});
			})
		);
		return;
	}

	// Default: network with cache fallback
	event.respondWith(
		fetch(event.request).catch(() => caches.match(event.request))
	);
});
