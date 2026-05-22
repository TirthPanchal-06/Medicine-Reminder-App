// Service Worker for Smart Medicine Reminder App (Web Push Notifications)

self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(self.clients.claim());
});

// 1. Listen for push notification events sent by the Node.js backend
self.addEventListener('push', function(event) {
  console.log('[ServiceWorker] Push message received.');

  let payload = {
    title: 'Medicine Reminder 💊',
    body: 'Time to take your scheduled dose!',
    data: {}
  };

  if (event.data) {
    try {
      payload = event.data.json();
    } catch (e) {
      payload.body = event.data.text();
    }
  }

  const options = {
    body: payload.body,
    icon: '/favicon.png',
    badge: '/icons/Icon-192.png',
    vibrate: [200, 100, 200],
    data: payload.data || {},
    actions: [
      { action: 'open', title: 'Open App' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification(payload.title, options)
  );
});

// 2. Listen for notification click events to focus/open the application
self.addEventListener('notificationclick', function(event) {
  console.log('[ServiceWorker] Notification clicked.');

  event.notification.close();

  // Handle click action
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // If a window is already open, focus it
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if ('focus' in client) {
          return client.focus();
        }
      }
      // Otherwise, open a new window
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
