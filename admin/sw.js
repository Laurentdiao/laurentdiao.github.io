self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(clearAdminCaches());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    clearAdminCaches().then(() => self.registration.unregister()).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', () => {});

function clearAdminCaches() {
  return caches.keys().then((keys) => Promise.all(
    keys.filter((key) => key.startsWith('winnie-blog-admin')).map((key) => caches.delete(key))
  ));
}
