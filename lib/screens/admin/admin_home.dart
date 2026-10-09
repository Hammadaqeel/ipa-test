import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/wayo_map.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  static const _titles = ['Overview', 'Rides', 'Drivers'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= 900;
    final pages = const [_OverviewTab(), _RidesTab(), _DriversTab()];

    final appBar = AppBar(
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      title: Text('${Brand.name} Admin · ${_titles[_tab]}'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Chip(
            avatar: const Icon(Icons.circle, size: 10, color: AppColors.ok),
            label: Text('${app.onlineDrivers} drivers online'),
          ),
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: app.pendingCount > 0,
                    label: Text('${app.pendingCount}'),
                    child: const Icon(Icons.dashboard_outlined),
                  ),
                  selectedIcon: const Icon(Icons.dashboard),
                  label: const Text('Overview'),
                ),
                const NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Rides')),
                const NavigationRailDestination(
                    icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: Text('Drivers')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: IndexedStack(index: _tab, children: pages)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: app.pendingCount > 0,
              label: Text('${app.pendingCount}'),
              child: const Icon(Icons.dashboard_outlined),
            ),
            label: 'Overview',
          ),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Rides'),
          const NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Drivers'),
        ],
      ),
    );
  }
}

// =============================================================== OVERVIEW

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth - 32;
      final cols = w >= 900 ? 6 : (w >= 560 ? 3 : 2);
      final cardW = (w - 12 * (cols - 1)) / cols;

      Widget stat(String label, String value, IconData icon, Color color) => SizedBox(
            width: cardW,
            child: RoundedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
          );

      final stats = Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          stat('Total rides', '${app.totalRides}', Icons.receipt_long, AppColors.primary),
          stat('Needs driver', '${app.pendingCount}', Icons.hourglass_top, AppColors.accent),
          stat('Live now', '${app.activeCount}', Icons.directions_car, AppColors.info),
          stat('Completed', '${app.completedCount}', Icons.check_circle, AppColors.ok),
          stat('Revenue', money(app.revenue), Icons.payments, const Color(0xFF7B5BD6)),
          stat('Platform fee', money(app.commission), Icons.account_balance, AppColors.danger),
        ],
      );

      final mapCard = RoundedCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text('Live fleet map', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            SizedBox(
              height: 380,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _FleetMap(app: app),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 10, 8, 4),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _Legend(color: AppColors.ok, label: 'Available'),
                  _Legend(color: AppColors.info, label: 'On trip'),
                  _Legend(color: AppColors.muted, label: 'Offline'),
                  _Legend(color: AppColors.accent, label: 'Waiting pickup'),
                ],
              ),
            ),
          ],
        ),
      );

      final queue = _AttentionList(app: app);
      final wide = c.maxWidth >= 900;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          stats,
          const SizedBox(height: 16),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: mapCard),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: queue),
              ],
            )
          else ...[
            mapCard,
            const SizedBox(height: 16),
            queue,
          ],
        ],
      );
    });
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 11, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      ],
    );
  }
}

class _FleetMap extends StatelessWidget {
  final AppState app;
  const _FleetMap({required this.app});

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    final lines = <Polyline>[];

    for (final r in app.rides) {
      if (r.status == RideStatus.requested || r.status == RideStatus.assigned) {
        markers.add(pinMarker(r.pickup.point, AppColors.accent, Icons.person_pin_circle,
            tooltip: '${r.id} · ${r.customerName}', size: 32));
      } else if (r.status.isLive) {
        lines.add(Polyline(
          points: r.activePath.length > 1 ? r.activePath : r.path,
          strokeWidth: 4,
          color: AppColors.info.withAlpha(160),
        ));
      }
    }
    for (final d in app.drivers) {
      if (d.blocked) continue;
      final st = app.statusOf(d);
      markers.add(pinMarker(d.position, st.color, d.vehicle.icon,
          tooltip: '${d.name} · ${st.label}', size: 38));
    }

    return WayoMap(center: Brand.cityCenter, zoom: 11.8, markers: markers, polylines: lines);
  }
}

class _AttentionList extends StatelessWidget {
  final AppState app;
  const _AttentionList({required this.app});

  @override
  Widget build(BuildContext context) {
    final needs = app.rides
        .where((r) => r.status == RideStatus.requested || r.status == RideStatus.assigned)
        .toList();
    final live = app.rides.where((r) => r.status.isLive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Needs assignment (${needs.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (needs.isEmpty)
          const RoundedCard(child: Text('All rides are covered. Nice!', style: TextStyle(color: AppColors.muted))),
        for (final r in needs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AdminRideTile(ride: r),
          ),
        const SizedBox(height: 10),
        Text('Live trips (${live.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (live.isEmpty)
          const RoundedCard(child: Text('No trips in progress.', style: TextStyle(color: AppColors.muted))),
        for (final r in live)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AdminRideTile(ride: r),
          ),
      ],
    );
  }
}

class _AdminRideTile extends StatelessWidget {
  final Ride ride;
  const _AdminRideTile({required this.ride});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final driver = ride.driverId == null ? null : app.driverById(ride.driverId!);
    final canAssign = ride.status == RideStatus.requested || ride.status == RideStatus.assigned;

    Widget? action;
    if (canAssign) {
      action = Row(
        children: [
          if (driver != null) ...[
            DriverAvatar(driver: driver, radius: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Sent to ${driver.name}, awaiting confirm',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ),
          ] else
            const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 38)),
            onPressed: () => showAssignDialog(context, ride),
            child: Text(driver == null ? 'Assign' : 'Re-assign'),
          ),
        ],
      );
    } else if (driver != null) {
      action = Row(
        children: [
          DriverAvatar(driver: driver, radius: 14),
          const SizedBox(width: 8),
          Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.gps_fixed, size: 15, color: AppColors.info),
          const SizedBox(width: 4),
          Text(
            ride.status == RideStatus.inTrip ? '${app.etaMinutes(ride).round()} min left' : 'to pickup',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      );
    }

    return RideTile(
      ride: ride,
      showCustomer: true,
      action: action,
      onTap: () => showRideDetail(context, ride.id, admin: true),
    );
  }
}

// ================================================================== RIDES

class _RidesTab extends StatefulWidget {
  const _RidesTab();

  @override
  State<_RidesTab> createState() => _RidesTabState();
}

class _RidesTabState extends State<_RidesTab> {
  String _filter = 'All';
  static const _filters = ['All', 'Pending', 'Live', 'Completed', 'Cancelled'];

  bool _match(Ride r) {
    switch (_filter) {
      case 'Pending':
        return r.status == RideStatus.requested || r.status == RideStatus.assigned;
      case 'Live':
        return r.status.isLive;
      case 'Completed':
        return r.status == RideStatus.completed;
      case 'Cancelled':
        return r.status == RideStatus.cancelled;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final rides = app.rides.where(_match).toList();

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              for (final f in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: rides.isEmpty
              ? const Center(child: Text('No rides in this view.', style: TextStyle(color: AppColors.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _AdminRideTile(ride: rides[i]),
                ),
        ),
      ],
    );
  }
}

// ================================================================ DRIVERS

class _DriversTab extends StatelessWidget {
  const _DriversTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: app.drivers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final d = app.drivers[i];
        final st = app.statusOf(d);
        final current = app.activeRideForDriver(d.id);
        return RoundedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DriverAvatar(driver: d, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('${d.vehicle.label} · ${d.model} · ${d.plate}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        Text(d.phone, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  StatusChip.driver(st),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  _miniStat('Trips', '${d.trips}'),
                  _miniStat('Rating', d.rating.toStringAsFixed(1)),
                  _miniStat('Earned', money(d.earnings)),
                  const Spacer(),
                  Column(
                    children: [
                      const Text('Active', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      Switch(value: !d.blocked, onChanged: (_) => app.toggleBlock(d.id)),
                    ],
                  ),
                ],
              ),
              if (current != null) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => showRideDetail(context, current.id, admin: true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.gps_fixed, size: 16, color: AppColors.info),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${current.id}: ${current.pickup.name} → ${current.dropoff.name}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppColors.info)),
                        ),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.info),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String k, String v) => Padding(
        padding: const EdgeInsets.only(right: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
