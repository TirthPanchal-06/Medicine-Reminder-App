// Conditional import bridge to prevent compiler crashes on mobile devices while preserving Web Push notifications on browser environments.
export 'web_helper_non_web.dart'
    if (dart.library.js) 'web_helper_web.dart';
