
const cachesVersion = '2023-12-28';

const noCacheUrlBeginnings = [
  'https://wasm-git.petersalomonsen.com'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.open(cachesVersion).then(cache =>
      cache.match(event.request).then((resp) => {        
        return resp || fetch(event.request).then((response) => {
          if (
            noCacheUrlBeginnings.findIndex(urlBeginning =>
              event.request.url.indexOf(urlBeginning) === 0)
            === -1
          ) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      }).catch((err) => {
        return new Response(null, { status: 500, statusText: err.message });
      })
    )
  );
});
