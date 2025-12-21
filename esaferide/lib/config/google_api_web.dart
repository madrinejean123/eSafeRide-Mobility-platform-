// Web implementation: try to read the API key from a meta tag in index.html
// (meta name="google-maps-api-key" content="...") or from a compile-time
// environment variable if provided during build.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String _readMetaKey() {
  try {
    final meta = html.document.querySelector(
      'meta[name="google-maps-api-key"]',
    );
    final content = meta?.getAttribute('content');
    if (content != null && content.isNotEmpty) return content;
  } catch (_) {}
  return '';
}

const String _compileTime = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: '',
);

final String googleMapsApiKey = (() {
  // Prefer runtime meta tag (so you don't need to rebuild to change the key on web).
  final meta = _readMetaKey();
  if (meta.isNotEmpty) return meta;
  if (_compileTime.isNotEmpty) return _compileTime;
  return '';
})();
