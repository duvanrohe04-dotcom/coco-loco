// Service worker "limpiador". Se publica con el nombre flutter_service_worker.js para que los
// dispositivos que ya tenían instalado el service worker viejo (que servía versiones antiguas
// del juego) lo descarguen, borren todo lo guardado, se desinstalen y recarguen la página.
// La versión nueva del juego ya no registra ningún service worker, así que no vuelve a pasar.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
    } catch (_) {}
    try {
      await self.registration.unregister();
    } catch (_) {}
    try {
      const clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach((c) => c.navigate(c.url));
    } catch (_) {}
  })());
});

// Mientras tanto no intercepta nada: todo va directo a la red.
self.addEventListener('fetch', () => {});
