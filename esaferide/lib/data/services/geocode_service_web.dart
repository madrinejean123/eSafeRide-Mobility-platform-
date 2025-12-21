// Web-specific implementation using the Google Maps JavaScript API via JS interop.
// This avoids CORS issues that occur when calling the Places/Geocoding HTTP
// endpoints directly from the browser.
//
// Lints: this file intentionally imports web-only libraries and uses
// JS interop. Silence analyzer warnings for those cases.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use,
// depend_on_referenced_packages, non_constant_identifier_names, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:js/js.dart' show allowInterop;

/// Poll for window.google availability for a short timeout. Returns true if
/// available, false after timeout.
Future<bool> _waitForGoogle({int timeoutMs = 3000}) async {
  final sw = Stopwatch()..start();
  while (true) {
    final g = js_util.getProperty(html.window, 'google');
    if (g != null) return true;
    if (sw.elapsedMilliseconds > timeoutMs) return false;
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

// Proxy helper — by default point to localhost:8080 where the example proxy
// lives. You can override by adding a meta tag in `web/index.html`:
// <meta name="places-proxy-url" content="http://localhost:8080" />
String _getProxyBase() {
  try {
    final meta = html.document.querySelector('meta[name="places-proxy-url"]');
    final content = meta?.getAttribute('content');
    if (content != null && content.isNotEmpty) return content;
  } catch (_) {}
  return 'http://localhost:8080';
}

Future<List<Map<String, String>>> _proxyAutocomplete(String input) async {
  try {
    final base = _getProxyBase();
    final url = '$base/autocomplete?input=${Uri.encodeComponent(input)}';
    final txt = await html.HttpRequest.getString(url);
    final json = jsonDecode(txt) as Map<String, dynamic>;
    final predictions = json['predictions'] as List<dynamic>?;
    if (predictions == null) return [];
    return predictions.map((p) {
      final m = p as Map<String, dynamic>;
      return {
        'description': m['description'] as String? ?? '',
        'place_id': m['place_id'] as String? ?? '',
      };
    }).toList();
  } catch (e) {
    debugPrint('[geocode_web] proxyAutocomplete error: $e');
    return [];
  }
}

Future<Map<String, double>?> _proxyDetails(String placeId) async {
  try {
    final base = _getProxyBase();
    final url = '$base/details?place_id=${Uri.encodeComponent(placeId)}';
    final txt = await html.HttpRequest.getString(url);
    final json = jsonDecode(txt) as Map<String, dynamic>;
    final result = json['result'] as Map<String, dynamic>?;
    if (result == null) return null;
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    if (loc == null) return null;
    final lat = (loc['lat'] as num).toDouble();
    final lng = (loc['lng'] as num).toDouble();
    return {'lat': lat, 'lng': lng};
  } catch (e) {
    debugPrint('[geocode_web] proxyDetails error: $e');
    return null;
  }
}

Future<String?> _proxyGeocode(double lat, double lng) async {
  try {
    final base = _getProxyBase();
    final url =
        '$base/geocode?lat=${Uri.encodeComponent(lat.toString())}&lng=${Uri.encodeComponent(lng.toString())}';
    final txt = await html.HttpRequest.getString(url);
    final json = jsonDecode(txt) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final formatted = first['formatted_address'] as String?;
    return formatted;
  } catch (e) {
    debugPrint('[geocode_web] proxyGeocode error: $e');
    return null;
  }
}

Future<String?> resolveLabel(double lat, double lng) async {
  final completer = Completer<String?>();
  try {
    // Wait briefly for the Google Maps JS to be available (script loads async).
    final ok = await _waitForGoogle();
    if (!ok) {
      debugPrint('[geocode_web] google maps JS not available (resolveLabel)');
      return null;
    }
    final google = js_util.getProperty(html.window, 'google');
    if (google == null) return null;
    debugPrint('[geocode_web] resolveLabel calling geocode for $lat,$lng');
    final maps = js_util.getProperty(google, 'maps');
    final geocoderCtor = js_util.getProperty(maps, 'Geocoder');
    final geocoder = js_util.callConstructor(geocoderCtor, []);
    js_util.callMethod(geocoder, 'geocode', [
      js_util.jsify({
        'location': js_util.jsify({'lat': lat, 'lng': lng}),
      }),
      allowInterop((results, status) {
        try {
          debugPrint('[geocode_web] geocode callback status: $status');
          if (status != null && status.toString() != 'OK') {
            // fallback to proxy
            _proxyGeocode(lat, lng)
                .then((label) {
                  completer.complete(label);
                })
                .catchError((e) {
                  debugPrint('[geocode_web] proxyGeocode fallback failed: $e');
                  completer.complete(null);
                });
            return;
          }
          if (results == null) {
            completer.complete(null);
            return;
          }
          final first = js_util.getProperty(results, 0);
          final formatted =
              js_util.getProperty(first, 'formatted_address') as String?;
          debugPrint('[geocode_web] resolved label: $formatted');
          completer.complete(formatted);
        } catch (e) {
          debugPrint('[geocode_web] geocode callback exception: $e');
          completer.complete(null);
        }
      }),
    ]);
  } catch (_) {
    completer.complete(null);
  }
  return completer.future;
}

Future<List<Map<String, String>>> placeAutocomplete(
  String input, {
  String? sessionToken,
}) async {
  final completer = Completer<List<Map<String, String>>>();
  try {
    final ok = await _waitForGoogle();
    if (!ok) {
      debugPrint(
        '[geocode_web] google maps JS not available (placeAutocomplete)',
      );
      return [];
    }
    final google = js_util.getProperty(html.window, 'google');
    if (google == null) return [];
    debugPrint('[geocode_web] placeAutocomplete input: $input');
    final maps = js_util.getProperty(google, 'maps');
    final places = js_util.getProperty(maps, 'places');
    final autocompleteServiceCtor = js_util.getProperty(
      places,
      'AutocompleteService',
    );
    final service = js_util.callConstructor(autocompleteServiceCtor, []);

    js_util.callMethod(service, 'getPlacePredictions', [
      js_util.jsify({'input': input}),
      allowInterop((predictions, status) {
        try {
          debugPrint(
            '[geocode_web] placeAutocomplete callback status: $status',
          );
          if (status != null && status.toString() != 'OK') {
            // fallback to proxy
            _proxyAutocomplete(input)
                .then((res) {
                  completer.complete(res);
                })
                .catchError((e) {
                  debugPrint('[geocode_web] proxyAutocomplete error: $e');
                  completer.complete([]);
                });
            return;
          }
          if (predictions == null) {
            completer.complete([]);
            return;
          }
          final int len = js_util.getProperty(predictions, 'length') as int;
          debugPrint('[geocode_web] predictions length: $len');
          final out = <Map<String, String>>[];
          for (var i = 0; i < len; i++) {
            final p = js_util.getProperty(predictions, i);
            final description =
                js_util.getProperty(p, 'description') as String? ?? '';
            final placeId = js_util.getProperty(p, 'place_id') as String? ?? '';
            out.add({'description': description, 'place_id': placeId});
          }
          debugPrint('[geocode_web] placeAutocomplete results: $out');
          completer.complete(out);
        } catch (e) {
          debugPrint('[geocode_web] placeAutocomplete callback exception: $e');
          completer.complete([]);
        }
      }),
    ]);
  } catch (_) {
    completer.complete([]);
  }
  return completer.future;
}

Future<Map<String, double>?> placeDetailsLatLng(String placeId) async {
  final completer = Completer<Map<String, double>?>();
  try {
    final ok = await _waitForGoogle();
    if (!ok) {
      debugPrint('[geocode_web] google maps JS not available (placeDetails)');
      return null;
    }
    final google = js_util.getProperty(html.window, 'google');
    if (google == null) return null;
    final maps = js_util.getProperty(google, 'maps');
    debugPrint('[geocode_web] placeDetails for $placeId');

    final places = js_util.getProperty(maps, 'places');
    // PlacesService needs an HTML node; we can provide a detached div.
    final element = html.DivElement();
    final placesServiceCtor = js_util.getProperty(places, 'PlacesService');
    final service = js_util.callConstructor(placesServiceCtor, [element]);

    js_util.callMethod(service, 'getDetails', [
      js_util.jsify({
        'placeId': placeId,
        'fields': ['geometry', 'formatted_address'],
      }),
      allowInterop((result, status) {
        try {
          debugPrint('[geocode_web] placeDetails callback status: $status');
          if (status != null && status.toString() != 'OK') {
            // fallback to proxy details
            _proxyDetails(placeId)
                .then((d) {
                  completer.complete(d);
                })
                .catchError((e) {
                  debugPrint('[geocode_web] proxyDetails error: $e');
                  completer.complete(null);
                });
            return;
          }
          if (result == null ||
              result['geometry'] == null ||
              result['geometry']['location'] == null) {
            completer.complete(null);
            return;
          }
          final lat =
              (js_util.callMethod(result['geometry']['location'], 'lat', [])
                      as num)
                  .toDouble();
          final lng =
              (js_util.callMethod(result['geometry']['location'], 'lng', [])
                      as num)
                  .toDouble();
          completer.complete({'lat': lat, 'lng': lng});
        } catch (e) {
          debugPrint('[geocode_web] placeDetails exception: $e');
          completer.complete(null);
        }
      }),
    ]);
  } catch (_) {
    completer.complete(null);
  }
  return completer.future;
}
