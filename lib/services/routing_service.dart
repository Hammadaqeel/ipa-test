import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/brand.dart';
import '../models/models.dart';

class RouteResult {
  final List<LatLng> points;
  final double km;
  final double minutes;
  final bool estimated;
  const RouteResult(this.points, this.km, this.minutes, {this.estimated = false});
}

/// Real road routing via the public OSRM demo server and place search via
/// OpenStreetMap Nominatim. Both are free demo endpoints: for production,
/// point these at your own OSRM/Valhalla/GraphHopper + geocoder (or a paid API).
/// If the network call fails, we fall back to a straight-line estimate so the
/// app never breaks.
class RoutingService {
  static const _dist = Distance();

  static List<LatLng> straightLine(LatLng a, LatLng b, {int steps = 40}) {
    return List.generate(steps + 1, (i) {
      final t = i / steps;
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
    });
  }

  static double km(LatLng a, LatLng b) => _dist.as(LengthUnit.Kilometer, a, b);

  static RouteResult _fallback(LatLng a, LatLng b) {
    final d = km(a, b) * 1.3;
    final mins = (d / 28 * 60).clamp(2, 600).toDouble();
    return RouteResult(straightLine(a, b), d, mins, estimated: true);
  }

  static Future<RouteResult> route(LatLng a, LatLng b) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _fallback(a, b);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List;
      if (routes.isEmpty) return _fallback(a, b);
      final route = routes.first as Map<String, dynamic>;
      final coords = (route['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (coords.length < 2) return _fallback(a, b);
      final distKm = (route['distance'] as num).toDouble() / 1000;
      // The OSRM demo reports free-flow time; pad it for city traffic.
      final mins = ((route['duration'] as num).toDouble() / 60 * 1.35).clamp(2, 600).toDouble();
      return RouteResult(coords, distKm, mins);
    } catch (_) {
      return _fallback(a, b);
    }
  }

  static Future<List<Place>> search(String query) async {
    if (query.trim().length < 3) return [];
    try {
      // Search the entire United States and return English labels.
      // This keeps the prototype usable across major U.S. cities rather than
      // locking search to a single service-city bounding box.
      final url = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '8',
        'countrycodes': 'us',
        'addressdetails': '1',
        'accept-language': 'en-US,en',
      });
      final res = await http
          .get(url, headers: kIsWeb ? null : {'User-Agent': Brand.userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        final display = (m['display_name'] as String).split(',');
        return Place(
          name: display.first.trim(),
          address: display.skip(1).take(3).join(',').trim(),
          point: LatLng(double.parse(m['lat'] as String), double.parse(m['lon'] as String)),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
