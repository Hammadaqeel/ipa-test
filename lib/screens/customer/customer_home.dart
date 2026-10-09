import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../models/models.dart';
import '../../services/routing_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/wayo_map.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [_BookTab(), _TripsTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Ride'),
          NavigationDestination(icon: Icon(Icons.history), label: 'My trips'),
        ],
      ),
    );
  }
}

// ============================================================ BOOK TAB

class _BookTab extends StatefulWidget {
  const _BookTab();

  @override
  State<_BookTab> createState() => _BookTabState();
}

class _BookTabState extends State<_BookTab> {
  final _map = MapController();
  final _search = TextEditingController();
  Timer? _debounce;

  Place _pickup = Place(
    name: 'Current location',
    address: 'Manhattan, New York, NY',
    point: Brand.cityCenter,
  );
  Place? _dropoff;
  bool _settingPickup = false;
  VehicleType _vehicle = VehicleType.mini;
  String _payment = 'Cash';
  RouteResult? _route;
  bool _loadingRoute = false;
  bool _searching = false;
  List<Place> _results = [];
  String? _fittedRide;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setPlace(Place p) {
    setState(() {
      if (_settingPickup) {
        _pickup = p;
      } else {
        _dropoff = p;
      }
      _results = [];
      _search.clear();
    });
    FocusScope.of(context).unfocus();
    if (_settingPickup && _dropoff == null) {
      moveMap(_map, p.point, 15);
    }
    _loadRoute();
  }

  void _onMapTap(LatLng p) {
    _setPlace(Place(
      name: 'Pinned location',
      address: '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}',
      point: p,
    ));
  }

  Future<void> _loadRoute() async {
    final drop = _dropoff;
    if (drop == null) {
      setState(() => _route = null);
      return;
    }
    setState(() => _loadingRoute = true);
    final r = await RoutingService.route(_pickup.point, drop.point);
    if (!mounted) return;
    setState(() {
      _route = r;
      _loadingRoute = false;
    });
    fitMap(_map, [_pickup.point, drop.point, ...r.points],
        inset: EdgeInsets.fromLTRB(40, 110, 40, MediaQuery.of(context).size.height * 0.5));
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 550), () async {
      final res = await RoutingService.search(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _searching = false;
      });
    });
  }

  void _book() {
    final app = context.read<AppState>();
    app.createRide(
      pickup: _pickup,
      dropoff: _dropoff!,
      vehicle: _vehicle,
      route: _route!,
      payment: _payment,
    );
    setState(() {
      _dropoff = null;
      _route = null;
      _results = [];
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final active = app.activeCustomerRide;
    final rating = app.ratingPendingRide;
    final driver = (active?.driverId != null) ? app.driverById(active!.driverId!) : null;

    // Fit the map once when a ride starts.
    if (active != null && _fittedRide != active.id) {
      _fittedRide = active.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fitMap(_map, [active.pickup.point, active.dropoff.point],
            inset: EdgeInsets.fromLTRB(40, 110, 40, MediaQuery.of(context).size.height * 0.5));
      });
    }

    final markers = <Marker>[];
    final lines = <Polyline>[];

    if (active != null) {
      markers.add(pinMarker(active.pickup.point, AppColors.ok, Icons.my_location, tooltip: 'Pickup'));
      markers.add(pinMarker(active.dropoff.point, AppColors.danger, Icons.flag, tooltip: 'Drop-off'));
      lines.add(Polyline(points: active.path, strokeWidth: 5, color: AppColors.primary.withAlpha(120)));
      if (driver != null && active.status.isLive) {
        markers.add(pinMarker(driver.position, AppColors.info, active.vehicle.icon,
            tooltip: driver.name, size: 44));
      }
    } else {
      markers.add(pinMarker(_pickup.point, AppColors.ok, Icons.my_location, tooltip: 'Pickup'));
      if (_dropoff != null) {
        markers.add(pinMarker(_dropoff!.point, AppColors.danger, Icons.flag, tooltip: 'Drop-off'));
      }
      if (_route != null) {
        lines.add(Polyline(points: _route!.points, strokeWidth: 5, color: AppColors.primary));
      }
      // Nearby available drivers of the chosen type.
      for (final d in app.drivers) {
        if (app.statusOf(d) == DriverStatus.available && d.vehicle == _vehicle) {
          markers.add(Marker(
            point: d.position,
            width: 30,
            height: 30,
            child: mapPin(color: AppColors.muted, icon: d.vehicle.icon, size: 30),
          ));
        }
      }
    }

    final mq = MediaQuery.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: WayoMap(
            controller: _map,
            center: Brand.cityCenter,
            zoom: 13.2,
            markers: markers,
            polylines: lines,
            onTap: active == null && rating == null ? _onMapTap : null,
          ),
        ),
        // Top bar
        Positioned(
          top: mq.padding.top + 10,
          left: 12,
          right: 12,
          child: Row(
            children: [
              _RoundBtn(icon: Icons.arrow_back, onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8)],
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text('${Brand.name} · Hi, ${app.customerName.split(' ').first}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bottom panel
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.56, maxWidth: 640),
            child: Material(
              color: Colors.white,
              elevation: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: rating != null
                    ? _ratingPanel(app, rating)
                    : active != null
                        ? _trackingPanel(app, active, driver)
                        : _bookingPanel(app),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- booking

  Widget _handle() => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
        ),
      );

  Widget _bookingPanel(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        const Text('Plan your ride', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        const SizedBox(height: 4),
        const Text('Reliable rides across the United States', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text('Drop-off'), icon: Icon(Icons.flag, size: 18)),
            ButtonSegment(value: true, label: Text('Pickup'), icon: Icon(Icons.my_location, size: 18)),
          ],
          selected: {_settingPickup},
          onSelectionChanged: (s) => setState(() => _settingPickup = s.first),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: _settingPickup ? 'Search pickup place' : 'Search any U.S. address, airport, or landmark',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
            isDense: true,
          ),
        ),
        if (_results.isNotEmpty)
          for (final p in _results)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _setPlace(p),
            ),
        if (_results.isEmpty && _dropoff == null) ...[
          const SizedBox(height: 10),
          const Text('POPULAR NEAR NEW YORK', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final p in AppState.places)
                ActionChip(
                  label: Text(p.name),
                  avatar: const Icon(Icons.place, size: 16),
                  onPressed: () => _setPlace(p),
                ),
            ],
          ),
        ],
        if (_dropoff != null) ...[
          const SizedBox(height: 12),
          RoundedCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                RouteLines(pickup: _pickup, dropoff: _dropoff!),
                if (_route != null) ...[
                  const Divider(height: 18),
                  Row(
                    children: [
                      const Icon(Icons.route, size: 16, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Text('${_route!.km.toStringAsFixed(1)} km · ${_route!.minutes.round()} min',
                          style: const TextStyle(color: AppColors.muted)),
                      if (_route!.estimated) ...[
                        const SizedBox(width: 6),
                        const Text('(estimate)', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingRoute)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_route != null) ...[
            _vehicleTile(app, VehicleType.mini),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.muted),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cash'),
                  selected: _payment == 'Cash',
                  onSelected: (_) => setState(() => _payment = 'Cash'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Wallet'),
                  selected: _payment == 'Wallet',
                  onSelected: (_) => setState(() => _payment = 'Wallet'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _book,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Confirm Premium Ride  ·  ${money(_vehicle.fareFor(_route!.km, _route!.minutes))}'),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _vehicleTile(AppState app, VehicleType v) {
    final sel = v == _vehicle;
    final fare = v.fareFor(_route!.km, _route!.minutes);
    final nearby = app.drivers
        .where((d) => app.statusOf(d) == DriverStatus.available && d.vehicle == v)
        .toList();
    String away = 'No drivers nearby';
    if (nearby.isNotEmpty) {
      final best = nearby
          .map((d) => RoutingService.km(d.position, _pickup.point))
          .reduce((a, b) => a < b ? a : b);
      away = '${(best / 25 * 60).ceil().clamp(1, 99)} min away';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _vehicle = v),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? AppColors.primary : const Color(0xFFE7E8EC), width: sel ? 2 : 1),
            color: sel ? const Color(0xFFFFF9EE) : Colors.white,
          ),
          child: Row(
            children: [
              Icon(v.icon, size: 30, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wayo Premium Sedan', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text('Private ride · up to 4 passengers · $away',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Text(money(fare), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- tracking

  Widget _trackingPanel(AppState app, Ride ride, Driver? driver) {
    String title;
    String sub = '';
    switch (ride.status) {
      case RideStatus.requested:
        title = 'Finding you a driver…';
        sub = 'Our dispatch team is matching the closest driver.';
        break;
      case RideStatus.assigned:
        title = 'Driver assigned';
        sub = 'Waiting for ${driver?.name ?? 'the driver'} to confirm.';
        break;
      case RideStatus.accepted:
        title = 'Driver is on the way';
        sub = 'Arriving in about ${app.etaMinutes(ride).round()} min';
        break;
      case RideStatus.arrived:
        title = 'Your driver has arrived';
        sub = 'Share your PIN with the driver to start the trip.';
        break;
      case RideStatus.inTrip:
        title = 'On your trip';
        sub = '${app.etaMinutes(ride).round()} min to ${ride.dropoff.name}';
        break;
      default:
        title = ride.status.label;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            StatusChip.ride(ride.status),
          ],
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: AppColors.muted)),
        ],
        if (ride.status == RideStatus.requested || ride.status == RideStatus.assigned) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 4),
        ],
        if (driver != null) ...[
          const SizedBox(height: 14),
          RoundedCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                DriverAvatar(driver: driver, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('${driver.model} · ${driver.plate}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      Row(children: [
                        const Icon(Icons.star, size: 16, color: AppColors.accent),
                        Text(' ${driver.rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calling ${driver.phone} (demo)')),
                  ),
                  icon: const Icon(Icons.call),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        RoundedCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              RouteLines(pickup: ride.pickup, dropoff: ride.dropoff),
              const Divider(height: 18),
              Row(
                children: [
                  Text(ride.vehicle.label, style: const TextStyle(color: AppColors.muted)),
                  const Spacer(),
                  Text('${ride.payment} · ${money(ride.fare)}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
        if (ride.status == RideStatus.accepted || ride.status == RideStatus.arrived) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Trip PIN (tell your driver)')),
                Text(ride.otp,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
              ],
            ),
          ),
        ],
        if (ride.status != RideStatus.inTrip) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => app.cancelRide(ride.id, 'customer'),
              child: const Text('Cancel ride'),
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ rating

  int _stars = 5;

  Widget _ratingPanel(AppState app, Ride ride) {
    final driver = ride.driverId == null ? null : app.driverById(ride.driverId!);
    return Column(
      children: [
        _handle(),
        const Icon(Icons.check_circle, color: AppColors.ok, size: 44),
        const SizedBox(height: 6),
        const Text('You have arrived', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('${money(ride.fare)} · ${ride.payment}', style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 14),
        Text('How was your ride with ${driver?.name ?? 'your driver'}?'),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => setState(() => _stars = i),
                icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: AppColors.accent, size: 36),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => app.rateRide(ride.id, _stars),
            child: const Text('Submit rating'),
          ),
        ),
        TextButton(onPressed: () => app.rateRide(ride.id, 0), child: const Text('Skip')),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon)),
      ),
    );
  }
}

// ============================================================ TRIPS TAB

class _TripsTab extends StatelessWidget {
  const _TripsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final rides = app.customerRides;
    return Scaffold(
      appBar: AppBar(title: const Text('My trips')),
      body: rides.isEmpty
          ? const Center(child: Text('No trips yet. Book your first ride!'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => RideTile(
                ride: rides[i],
                onTap: () => showRideDetail(context, rides[i].id),
              ),
            ),
    );
  }
}
