var CACHE_NAME = 'behaviorlog-v1';
var SHELL_FILES = [
  '/app.html',
  '/index.html',
  '/QABF_Assessment.html',
  '/FAST_Assessment.html',
  '/privacy.html'
];

// Install — cache app shell
self.addEventListener('install', function(e) {
  e.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      return cache.addAll(SHELL_FILES);
    }).then(function() {
      return self.skipWaiting();
    })
  );
});

// Activate — clean old caches
self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys.filter(function(k) { return k !== CACHE_NAME; })
            .map(function(k) { return caches.delete(k); })
      );
    }).then(function() {
      return self.clients.claim();
    })
  );
});

// Fetch — network first for API/Supabase, cache first for app shell
self.addEventListener('fetch', function(e) {
  var url = new URL(e.request.url);

  // Always go network-first for API calls, Supabase, and POST requests
  if (e.request.method !== 'GET' ||
      url.pathname.startsWith('/api/') ||
      url.hostname.includes('supabase')) {
    return;
  }

  // For CDN resources (Supabase JS), cache with network fallback
  if (url.hostname.includes('cdn.jsdelivr.net')) {
    e.respondWith(
      caches.match(e.request).then(function(cached) {
        if (cached) return cached;
        return fetch(e.request).then(function(response) {
          if (response.ok) {
            var clone = response.clone();
            caches.open(CACHE_NAME).then(function(cache) {
              cache.put(e.request, clone);
            });
          }
          return response;
        });
      })
    );
    return;
  }

  // App shell — network first, fall back to cache
  e.respondWith(
    fetch(e.request).then(function(response) {
      if (response.ok) {
        var clone = response.clone();
        caches.open(CACHE_NAME).then(function(cache) {
          cache.put(e.request, clone);
        });
      }
      return response;
    }).catch(function() {
      return caches.match(e.request).then(function(cached) {
        return cached || new Response('Offline — please reconnect to load this page.', {
          status: 503,
          headers: { 'Content-Type': 'text/plain' }
        });
      });
    })
  );
});
