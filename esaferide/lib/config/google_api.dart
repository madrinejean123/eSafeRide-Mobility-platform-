// Web-aware Google API key loader.
// This file conditionally imports a platform-specific implementation so that
// on mobile/desktop we read a compile-time env variable, while on web we try
// to read a meta tag placed in `web/index.html` (recommended) or fall back to
// a compile-time value if provided.

export 'google_api_io.dart' if (dart.library.html) 'google_api_web.dart';
