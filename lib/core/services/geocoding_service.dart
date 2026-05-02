import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  // This key is now loaded from the environment during the build process.
  // See the --dart-define-from-file flag in the build command.
  static const _apiKey = String.fromEnvironment('GEOCODING_API_KEY');

  /// Converts a human-readable address to (lat, lng).
  /// Returns null if geocoding fails or the key is not set.
  static Future<(double lat, double lng)?> geocode(String address) async {
    if (_apiKey.isEmpty) {
      debugPrint('GeocodingService: API key not set, skipping.');
      return null;
    }
    try {
      final encoded = Uri.encodeComponent(address.trim());
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=$_apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return null;
      final loc = body['results'][0]['geometry']['location'];
      return ((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return null;
    }
  }
}
