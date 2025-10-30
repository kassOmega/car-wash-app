const CACHE_NAME = "car-wash-manager-v1.0.1";
const urlsToCache = [
  "./",
  "./main.dart.js",
  "./index.html",
  "./manifest.json",
  "./icons/Icon-192.png",
  "./icons/Icon-512.png",
  "./assets/FontManifest.json",
  "./assets/AssetManifest.json",
  "./assets/packages/cupertino_icons/assets/CupertinoIcons.ttf",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(urlsToCache))
  );
});

self.addEventListener("fetch", (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request);
    })
  );
});
