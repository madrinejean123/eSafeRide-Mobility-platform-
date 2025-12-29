import 'package:flutter/services.dart';

class PlatformApiKey {
  static const MethodChannel _channel = MethodChannel('com.esaferide/api_key');

  /// Returns the Google Maps API key read from AndroidManifest meta-data
  /// (meta-data name: com.google.android.geo.API_KEY).
  /// Returns null if not available or on error.
  static Future<String?> getGoogleMapsApiKey() async {
    try {
      final String? key = await _channel.invokeMethod<String>(
        'getGoogleMapsApiKey',
      );
      if (key == null || key.isEmpty) return null;
      return key;
    } catch (_) {
      return null;
    }
  }

  /// Returns the deployed Directions Cloud Function URL stored as manifest meta-data
  /// with name `com.esaferide.directions_url` or null if not set.
  static Future<String?> getDirectionsFunctionUrl() async {
    try {
      final String? url = await _channel.invokeMethod<String>(
        'getDirectionsFunctionUrl',
      );
      if (url == null || url.isEmpty) return null;
      return url;
    } catch (_) {
      return null;
    }
  }
}
