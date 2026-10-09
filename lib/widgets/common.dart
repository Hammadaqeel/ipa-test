import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../models/models.dart';
import '../services/routing_service.dart';
import '../state/app_state.dart';
import 'wayo_map.dart';

String money(num v) {
  final s = v.round().toString();
  final withCommas = s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '${Brand.currency} $withCommas';
}

String clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
}

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  factory StatusChip.ride(RideStatus s) => StatusChip(label: s.label, color: s.color);
  factory StatusChip.driver(DriverStatus s) => StatusChip(label: s.label, color: s.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class RoundedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const RoundedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class RouteLines extends StatelessWidget {
  final Place pickup;
  final Place dropoff;
  const RouteLines({super.key, required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, Color c, Place p) => Row(
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.address.isEmpty ? p.name : '${p.name} · ${p.address}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          ],
        );
    return Column(
      children: [
        row(Icons.radio_button_checked, AppColors.ok, pickup),
        Padding(
          padding: const EdgeInsets.only(left: 7),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 2, height: 10, color: Colors.black26),
          ),
        ),
        row(Icons.location_on, AppColors.danger, dropoff),
      ],
    );
  }
}

class RideTile extends StatelessWidget {
  final Ride ride;
  final VoidCallback? onTap;
  final Widget? action;
  final bool showCustomer;
  const RideTile({
    super.key,
    required this.ride,
    this.onTap,
    this.action,
    this.showCustomer = false,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ride.vehicle.icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(ride.id, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text(ago(ride.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const Spacer(),
              StatusChip.ride(ride.status),
            ],
          ),
          const SizedBox(height: 10),
          RouteLines(pickup: ride.pickup, dropoff: ride.dropoff),
          const SizedBox(height: 10),
          Row(
            children: [
              if (showCustomer) ...[
                const Icon(Icons.person_outline, size: 16, color: AppColors.muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(ride.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
                const SizedBox(width: 12),
              ],
              Text('${ride.distanceKm.toStringAsFixed(1)} km · ${ride.durationMin.round()} min',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const Spacer(),
              Text(money(ride.fare), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}

class DriverAvatar extends StatelessWidget {
  final Driver driver;
  final double radius;
  const DriverAvatar({super.key, required this.driver, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withAlpha(30),
      child: Text(driver.initials,
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: radius * 0.7)),
    );
  }
}

/// Dialog for the admin to choose a driver for a ride (nearest first).
Future<void> showAssignDialog(BuildContext context, Ride ride) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final app = ctx.read<AppState>();
      final candidates = app.drivers
          .where((d) => app.statusOf(d) == DriverStatus.available)
          .toList()
        ..sort((a, b) => RoutingService.km(a.position, ride.pickup.point)
            .compareTo(RoutingService.km(b.position, ride.pickup.point)));
      return AlertDialog(
        title: Text('Assign ${ride.id}'),
        content: SizedBox(
          width: 380,
          child: candidates.isEmpty
              ? const Text('No drivers are available right now. Ask a driver to go online.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final d in candidates)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: DriverAvatar(driver: d),
                        title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${d.vehicle.label} · ${d.model}\n'
                          '${RoutingService.km(d.position, ride.pickup.point).toStringAsFixed(1)} km from pickup'
                          '${d.vehicle == ride.vehicle ? ' · matches request' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                          onPressed: () {
                            app.assignRide(ride.id, d.id);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${ride.id} assigned to ${d.name}')),
                            );
                          },
                          child: const Text('Assign'),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      );
    },
  );
}

void showRideDetail(BuildContext context, String rideId, {bool admin = false}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RideDetailSheet(rideId: rideId, admin: admin),
  );
}

/// Full ride detail with live mini-map and timeline. Used by all dashboards.
class RideDetailSheet extends StatelessWidget {
  final String rideId;
  final bool admin;
  const RideDetailSheet({super.key, required this.rideId, required this.admin});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ride = app.rideById(rideId);
    if (ride == null) return const SizedBox.shrink();
    final driver = ride.driverId == null ? null : app.driverById(ride.driverId!);

    final fit = <LatLng>[
      ride.pickup.point,
      ride.dropoff.point,
      if (driver != null && ride.status.isLive) driver.position,
    ];
    final markers = <Marker>[
      pinMarker(ride.pickup.point, AppColors.ok, Icons.my_location, tooltip: 'Pickup'),
      pinMarker(ride.dropoff.point, AppColors.danger, Icons.flag, tooltip: 'Drop-off'),
      if (driver != null && ride.status.isLive)
        pinMarker(driver.position, AppColors.info, ride.vehicle.icon, tooltip: driver.name),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(ride.id, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                StatusChip.ride(ride.status),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: WayoMap(
                  interactive: false,
                  fitPoints: fit,
                  markers: markers,
                  polylines: [
                    Polyline(points: ride.path, strokeWidth: 4, color: AppColors.primary.withAlpha(170)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            RoundedCard(child: RouteLines(pickup: ride.pickup, dropoff: ride.dropoff)),
            const SizedBox(height: 10),
            RoundedCard(
              child: Column(
                children: [
                  _kv('Fare', money(ride.fare), bold: true),
                  _kv('Vehicle', ride.vehicle.label),
                  _kv('Distance', '${ride.distanceKm.toStringAsFixed(1)} km'),
                  _kv('Est. duration', '${ride.durationMin.round()} min'),
                  _kv('Payment', ride.payment),
                  _kv('Requested', clock(ride.createdAt)),
                  if (admin) _kv('Platform fee', money(ride.fare * Brand.commission)),
                  if (ride.rating != null && ride.rating! > 0) _kv('Rating', '${ride.rating} / 5'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            RoundedCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0x1A3B7DD8),
                    child: Icon(Icons.person, color: AppColors.info),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Customer', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        Text(ride.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(ride.customerPhone, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            RoundedCard(
              child: driver == null
                  ? const Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: AppColors.muted),
                        SizedBox(width: 12),
                        Text('No driver yet', style: TextStyle(color: AppColors.muted)),
                      ],
                    )
                  : Row(
                      children: [
                        DriverAvatar(driver: driver),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Driver', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                              Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${driver.model} · ${driver.plate}',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                            ],
                          ),
                        ),
                        Row(children: [
                          const Icon(Icons.star, color: AppColors.accent, size: 18),
                          Text(driver.rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                      ],
                    ),
            ),
            if (admin && (ride.status == RideStatus.requested || ride.status == RideStatus.assigned)) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showAssignDialog(context, ride),
                icon: const Icon(Icons.assignment_ind),
                label: Text(ride.status == RideStatus.assigned ? 'Re-assign driver' : 'Assign driver'),
              ),
            ],
            if (admin && ride.status.isOpen && ride.status != RideStatus.inTrip) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => app.cancelRide(ride.id, 'admin'),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel ride'),
              ),
            ],
            const SizedBox(height: 18),
            const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            for (final e in ride.events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle, size: 9, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 68,
                      child: Text(clock(e.time),
                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                    ),
                    Expanded(child: Text(e.text, style: const TextStyle(fontSize: 13.5))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: AppColors.muted)),
            const Spacer(),
            Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );
}
