const CACHE_NAME = "car-wash-manager-v1.0.2";
const urlsToCache = [
  "./",
  "./index.html",
  "./main.dart.js",
  "./manifest.json",
  "./icons/Icon-192.png",
  "./icons/Icon-512.png",
  "./assets/FontManifest.json",
  "./assets/AssetManifest.json",
  "./assets/packages/cupertino_icons/assets/CupertinoIcons.ttf",
];

self.addEventListener("install", (event) => {
  console.log("Service Worker installing...");
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log("Opened cache");
      return cache.addAll(urlsToCache);
    })
  );
});

self.addEventListener("fetch", (event) => {
  // Skip non-GET requests
  if (event.request.method !== "GET") {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((response) => {
      // If found in cache, return it
      if (response) {
        return response;
      }

      // For navigation requests, always serve index.html (SPA behavior)
      if (event.request.mode === "navigate") {
        return caches.match("./index.html");
      }

      // For other requests, try network first
      return fetch(event.request).catch(() => {
        // If network fails and it's a document request, fall back to index.html
        if (event.request.destination === "document") {
          return caches.match("./index.html");
        }
        return null;
      });
    })
  );
});

self.addEventListener("activate", (event) => {
  console.log("Service Worker activating...");
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log("Deleting old cache:", cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});
