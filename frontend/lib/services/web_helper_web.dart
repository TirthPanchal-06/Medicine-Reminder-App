// JavaScript-interop implementation of web helpers.
import 'dart:js' as js;

void enableWebNotifications(String token) {
  try {
    js.context.callMethod('enableNotifications', [token]);
  } catch (e) {
    print('Error setting up web push notifications: $e');
  }
}
