import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/brand.dart';

/// Clean light map wrapper using real OpenStreetMap road tiles. No API key required.
class WayoMap extends StatelessWidget {
  final MapController? controller;
  final LatLng center;
  final double zoom;

  /// If given, the map opens fitted to these points instead of center/zoom.
  final List<LatLng>? fitPoints;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final void Function(LatLng point)? onTap;
  final bool interactive;

  const WayoMap({
    super.key,
    this.controller,
    this.center = Brand.cityCenter,
    this.zoom = 13,
    this.fitPoints,
    this.markers = const [],
    this.polylines = const [],
    this.onTap,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    final pts = fitPoints;
    final cb = onTap;
    final void Function(TapPosition, LatLng)? tapHandler =
        cb == null ? null : (TapPosition pos, LatLng point) => cb(point);
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 3,
        maxZoom: 18,
        initialCameraFit: (pts != null && pts.length >= 2)
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(pts),
                padding: const EdgeInsets.all(36),
                maxZoom: 16,
              )
            : null,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: tapHandler,
      ),
      children: [
        TileLayer(
          urlTemplate: Brand.tileUrl,
          userAgentPackageName: Brand.userAgent,
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
        ),
      ],
    );
  }
}

/// Safely fit a live map controller to some points (no-op if the map is not
/// ready yet).
void fitMap(MapController c, List<LatLng> points, {double padding = 60, EdgeInsets? inset}) {
  if (points.length < 2) return;
  try {
    c.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: inset ?? EdgeInsets.all(padding),
      maxZoom: 16,
    ));
  } catch (_) {}
}

void moveMap(MapController c, LatLng p, double zoom) {
  try {
    c.move(p, zoom);
  } catch (_) {}
}

Widget mapPin({required Color color, required IconData icon, double size = 38}) {
  return Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.55),
  );
}

Marker pinMarker(LatLng p, Color color, IconData icon, {String? tooltip, double size = 38}) {
  Widget w = mapPin(color: color, icon: icon, size: size);
  if (tooltip != null) w = Tooltip(message: tooltip, child: w);
  return Marker(point: p, width: size, height: size, child: w);
}
