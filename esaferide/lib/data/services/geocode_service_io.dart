import 'dart:convert';

import 'package:geocoding/geocoding.dart' as mobile_geo;
import 'package:http/http.dart' as http;

import '../../config/google_api.dart';

/// Resolve a human-friendly label for coordinates.
/// Uses platform geocoding where available; falls back to the Google
/// Geocoding HTTP API (useful for server / non-web clients).
Future<String?> resolveLabel(double lat, double lng) async {
  // Try platform geocoding on non-web first
  try {
    final places = await mobile_geo.placemarkFromCoordinates(lat, lng);
    if (places.isNotEmpty) {
      final p = places.first;
      final parts = [
        p.name,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].where((s) => s != null && s.isNotEmpty).cast<String>().toList();
      if (parts.isNotEmpty) return parts.join(', ');
    }
  } catch (_) {
    // fallthrough to HTTP fallback
  }

  // Fallback to Google Geocoding API (requires API key)
  if (googleMapsApiKey == 'YOUR_API_KEY' || googleMapsApiKey.isEmpty) {
    return null;
  }
  final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
    'latlng': '$lat,$lng',
    'key': googleMapsApiKey,
  });
  try {
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        final first = results.first as Map<String, dynamic>;
        final formatted = first['formatted_address'] as String?;
        if (formatted != null && formatted.isNotEmpty) return formatted;
      }
    }
  } catch (_) {}
  return null;
}

/// Use Google Places Autocomplete (HTTP) to fetch suggestions for input.
/// Returns list of maps { 'description': ..., 'place_id': ... }
Future<List<Map<String, String>>> placeAutocomplete(
  String input, {
  String? sessionToken,
}) async {
  if (googleMapsApiKey == 'YOUR_API_KEY' || googleMapsApiKey.isEmpty) {
    return [];
  }
  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/autocomplete/json',
    {
      'input': input,
      'key': googleMapsApiKey,
      'types': 'establishment|geocode',
      // Optionally restrict by country: 'components': 'country:ug'
    },
  );
  try {
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final predictions = json['predictions'] as List<dynamic>?;
      if (predictions != null) {
        return predictions.map((p) {
          final m = p as Map<String, dynamic>;
          return {
            'description': m['description'] as String? ?? '',
            'place_id': m['place_id'] as String? ?? '',
          };
        }).toList();
      }
    }
  } catch (_) {}
  return [];
}

/// Fetch place details (lat/lng) for a place_id via Place Details API.
Future<Map<String, double>?> placeDetailsLatLng(String placeId) async {
  if (googleMapsApiKey == 'YOUR_API_KEY' || googleMapsApiKey.isEmpty) {
    return null;
  }
  final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
    'place_id': placeId,
    'key': googleMapsApiKey,
    'fields': 'geometry,formatted_address',
  });
  try {
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = json['result'] as Map<String, dynamic>?;
      if (result != null &&
          result['geometry'] != null &&
          result['geometry']['location'] != null) {
        final loc = result['geometry']['location'] as Map<String, dynamic>;
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        return {'lat': lat, 'lng': lng};
      }
    }
  } catch (_) {}
  return null;
}
