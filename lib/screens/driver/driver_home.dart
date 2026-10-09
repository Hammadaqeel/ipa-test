import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand.dart';
import '../../models/models.dart';
import '../../services/routing_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/wayo_map.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final driver = app.currentDriver;
    final offers = app.offeredTo(driver.id).length;
    final status = app.statusOf(driver);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        titleSpacing: 0,
        title: PopupMenuButton<String>(
          tooltip: 'Switch demo driver',
          onSelected: (id) => app.currentDriverId = id,
          itemBuilder: (_) => [
            for (final d in app.drivers)
              PopupMenuItem(value: d.id, child: Text('${d.name} · ${d.vehicle.label}')),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DriverAvatar(driver: driver, radius: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(driver.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('${driver.vehicle.label} · ${driver.plate}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(status == DriverStatus.offline ? 'Offline' : 'Online',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: status == DriverStatus.offline ? AppColors.muted : AppColors.ok)),
                Switch(
                  value: driver.online,
                  onChanged: driver.blocked ? null : (v) => app.setDriverOnline(driver.id, v),
                ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _DriverMap(onSeeRequests: () => setState(() => _tab = 1)),
          const _RequestsTab(),
          const _EarningsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Drive'),
          NavigationDestination(
            icon: Badge(isLabelVisible: offers > 0, label: Text('$offers'), child: const Icon(Icons.list_alt)),
            label: 'Requests',
          ),
          const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Earnings'),
        ],
      ),
    );
  }
}

// =================================================================== MAP

class _DriverMap extends StatefulWidget {
  final VoidCallback onSeeRequests;
  const _DriverMap({required this.onSeeRequests});

  @override
  State<_DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<_DriverMap> {
  final _map = MapController();
  String? _fittedKey;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final driver = app.currentDriver;
    final ride = app.activeRideForDriver(driver.id);
    final offers = app.offeredTo(driver.id);
    final pool = app.openPool;
    final mq = MediaQuery.of(context);

    final key = ride == null ? 'idle_${driver.id}' : '${ride.id}_${ride.status.name}';
    if (_fittedKey != key) {
      _fittedKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ride != null) {
          final target = ride.status == RideStatus.inTrip ? ride.dropoff.point : ride.pickup.point;
          fitMap(_map, [driver.position, target],
              inset: EdgeInsets.fromLTRB(50, 60, 50, mq.size.height * 0.36));
        } else {
          moveMap(_map, driver.position, 14);
        }
      });
    }

    final markers = <Marker>[];
    final lines = <Polyline>[];
    if (ride != null) {
      if (ride.status == RideStatus.inTrip) {
        markers.add(pinMarker(ride.dropoff.point, AppColors.danger, Icons.flag, tooltip: 'Drop-off'));
      } else {
        markers.add(pinMarker(ride.pickup.point, AppColors.ok, Icons.my_location, tooltip: 'Pickup'));
      }
      if (ride.activePath.length > 1) {
        lines.add(Polyline(points: ride.activePath, strokeWidth: 5, color: AppColors.info));
      }
    } else if (driver.online) {
      // Show open requests as amber pins so the driver sees demand.
      for (final r in [...offers, ...pool]) {
        markers.add(pinMarker(r.pickup.point, AppColors.accent, Icons.person_pin_circle,
            tooltip: '${r.id} · ${money(r.fare)}', size: 34));
      }
    }
    markers.add(pinMarker(driver.position, AppColors.info, driver.vehicle.icon, tooltip: 'You', size: 46));

    return Stack(
      children: [
        Positioned.fill(
          child: WayoMap(controller: _map, center: driver.position, zoom: 14, markers: markers, polylines: lines),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.5, maxWidth: 640),
            child: Material(
              color: Colors.white,
              elevation: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: _panel(app, driver, ride, offers, pool),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(AppState app, Driver driver, Ride? ride, List<Ride> offers, List<Ride> pool) {
    if (driver.blocked) {
      return const _Notice(
        icon: Icons.block,
        color: AppColors.danger,
        title: 'Account suspended',
        text: 'Please contact support to reactivate your account.',
      );
    }
    if (ride != null) return _activeRidePanel(app, ride);

    if (!driver.online) {
      return const _Notice(
        icon: Icons.power_settings_new,
        color: AppColors.muted,
        title: "You're offline",
        text: 'Switch on the toggle at the top to start receiving ride requests.',
      );
    }

    if (offers.isNotEmpty) {
      final r = offers.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in, color: AppColors.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Dispatch sent you a ride',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Text(money(r.fare), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          _offerBody(app, driver, r),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Waiting for requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          pool.isEmpty
              ? 'No open requests right now. Stay online.'
              : '${pool.length} open request${pool.length > 1 ? 's' : ''} nearby. Pick one to start earning.',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.onSeeRequests,
            icon: const Icon(Icons.list_alt),
            label: Text(pool.isEmpty ? 'View requests' : 'View ${pool.length} open request${pool.length > 1 ? 's' : ''}'),
          ),
        ),
      ],
    );
  }

  Widget _offerBody(AppState app, Driver driver, Ride r) {
    return Column(
      children: [
        RoundedCard(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            RouteLines(pickup: r.pickup, dropoff: r.dropoff),
            const Divider(height: 18),
            Row(children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(r.customerName, style: const TextStyle(color: AppColors.muted)),
              const Spacer(),
              Text('${r.distanceKm.toStringAsFixed(1)} km · ${r.durationMin.round()} min',
                  style: const TextStyle(color: AppColors.muted)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => app.declineRide(r.id, driver.id),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => app.acceptRide(r.id, driver.id),
                child: const Text('Accept ride'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openUsNavigation(double latitude, double longitude) async {
    // Google Maps driving directions work across the United States and hand off
    // to the Maps app when installed, otherwise opening the web directions page.
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open navigation. Please check your connection.')),
      );
    }
  }

  Widget _activeRidePanel(AppState app, Ride ride) {
    String title;
    switch (ride.status) {
      case RideStatus.accepted:
        title = 'Head to pickup · ${app.etaMinutes(ride).round()} min';
        break;
      case RideStatus.arrived:
        title = 'Arrived at pickup';
        break;
      default:
        title = app.atDestination(ride)
            ? 'You have reached the destination'
            : 'Driving to drop-off · ${app.etaMinutes(ride).round()} min';
    }

    Widget action;
    if (ride.status == RideStatus.accepted) {
      action = FilledButton.icon(
        onPressed: () => _openUsNavigation(ride.pickup.point.latitude, ride.pickup.point.longitude),
        icon: const Icon(Icons.navigation_rounded),
        label: const Text('Navigate to pickup in Google Maps'),
      );
    } else if (ride.status == RideStatus.arrived) {
      action = FilledButton.icon(
        onPressed: () => _askOtp(app, ride),
        icon: const Icon(Icons.lock_open),
        label: const Text('Enter PIN & start trip'),
      );
    } else if (app.atDestination(ride)) {
      action = FilledButton.icon(
        onPressed: () => app.completeTrip(ride.id),
        icon: const Icon(Icons.payments),
        label: Text('Complete trip · collect ${money(ride.fare)}'),
      );
    } else {
      action = FilledButton.icon(
        onPressed: () => _openUsNavigation(ride.dropoff.point.latitude, ride.dropoff.point.longitude),
        icon: const Icon(Icons.navigation_rounded),
        label: const Text('Navigate to destination in Google Maps'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            StatusChip.ride(ride.status),
          ],
        ),
        const SizedBox(height: 10),
        RoundedCard(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              const CircleAvatar(
                backgroundColor: Color(0x1A3B7DD8),
                child: Icon(Icons.person, color: AppColors.info),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.customerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(ride.customerPhone, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Calling ${ride.customerPhone} (demo)')),
                ),
                icon: const Icon(Icons.call),
              ),
            ]),
            const Divider(height: 18),
            RouteLines(pickup: ride.pickup, dropoff: ride.dropoff),
            const Divider(height: 18),
            Row(children: [
              Text('${ride.distanceKm.toStringAsFixed(1)} km · ${ride.payment}',
                  style: const TextStyle(color: AppColors.muted)),
              const Spacer(),
              Text(money(ride.fare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: action),
        if (ride.status == RideStatus.accepted || ride.status == RideStatus.arrived)
          TextButton(
            onPressed: () => app.cancelRide(ride.id, 'driver'),
            child: const Text('Cancel ride', style: TextStyle(color: AppColors.danger)),
          ),
      ],
    );
  }

  Future<void> _askOtp(AppState app, Ride ride) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter customer PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ask the rider for the 4-digit PIN shown in their app.'),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              maxLength: 4,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w800),
            ),
            Text('Demo hint: PIN is ${ride.otp}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 42)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    final pin = c.text;
    if (ok != true || !mounted) return;
    if (!app.startTrip(ride.id, pin)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong PIN, try again')));
    }
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  const _Notice({required this.icon, required this.color, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================== REQUESTS

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final driver = app.currentDriver;
    final offers = app.offeredTo(driver.id);
    final busy = app.activeRideForDriver(driver.id) != null;
    final canPick = driver.online && !driver.blocked && !busy;

    final pool = app.openPool
      ..sort((a, b) => RoutingService.km(driver.position, a.pickup.point)
          .compareTo(RoutingService.km(driver.position, b.pickup.point)));

    Widget section(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
          child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!canPick)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              busy
                  ? 'Finish your current trip before taking another ride.'
                  : driver.blocked
                      ? 'Your account is suspended.'
                      : 'Go online to pick up rides.',
            ),
          ),
        section('Assigned to you (${offers.length})'),
        if (offers.isEmpty)
          const Text('Nothing assigned by dispatch.', style: TextStyle(color: AppColors.muted)),
        for (final r in offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RideTile(
              ride: r,
              showCustomer: true,
              onTap: () => showRideDetail(context, r.id),
              action: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => app.declineRide(r.id, driver.id),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: canPick ? () => app.acceptRide(r.id, driver.id) : null,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        section('Open requests (${pool.length})'),
        if (pool.isEmpty)
          const Text('No open requests right now.', style: TextStyle(color: AppColors.muted)),
        for (final r in pool)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RideTile(
              ride: r,
              showCustomer: true,
              onTap: () => showRideDetail(context, r.id),
              action: Row(
                children: [
                  Icon(Icons.near_me, size: 16, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    '${RoutingService.km(driver.position, r.pickup.point).toStringAsFixed(1)} km to pickup',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(110, 40)),
                    onPressed: canPick ? () => app.acceptRide(r.id, driver.id) : null,
                    child: const Text('Pick ride'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================== EARNINGS

class _EarningsTab extends StatelessWidget {
  const _EarningsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final driver = app.currentDriver;
    final done = app.ridesOfDriver(driver.id);

    Widget stat(String label, String value, IconData icon) => Expanded(
          child: RoundedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          stat('Total earnings', money(driver.earnings), Icons.account_balance_wallet),
          const SizedBox(width: 10),
          stat('Trips', '${driver.trips}', Icons.route),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          stat('Rating', driver.rating.toStringAsFixed(2), Icons.star),
          const SizedBox(width: 10),
          stat('Platform fee', '${(Brand.commission * 100).round()}%', Icons.percent),
        ]),
        const SizedBox(height: 18),
        const Text('Recent trips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (done.isEmpty) const Text('Completed trips will show up here.', style: TextStyle(color: AppColors.muted)),
        for (final r in done)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RideTile(ride: r, showCustomer: true, onTap: () => showRideDetail(context, r.id)),
          ),
      ],
    );
  }
}
