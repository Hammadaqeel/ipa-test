import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/brand.dart';
import '../models/models.dart';
import '../services/routing_service.dart';

/// In-memory store shared by all three dashboards. Replace the methods with
/// API / Firebase calls when a backend is added; the UI only talks to this.
class AppState extends ChangeNotifier {
  AppState({bool simulate = true}) {
    _seed();
    if (simulate) {
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  Timer? _timer;
  int _seq = 1006;

  // Demo customer identity.
  final String customerId = 'c1';
  final String customerName = 'Sara Khan';
  final String customerPhone = '+1 212 555 0148';

  final List<Ride> rides = [];
  final List<Driver> drivers = [];

  String _currentDriverId = 'd1';
  String get currentDriverId => _currentDriverId;
  set currentDriverId(String id) {
    _currentDriverId = id;
    notifyListeners();
  }

  Driver get currentDriver => driverById(_currentDriverId);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- lookups

  Driver driverById(String id) => drivers.firstWhere((d) => d.id == id);
  Ride? rideById(String id) {
    for (final r in rides) {
      if (r.id == id) return r;
    }
    return null;
  }

  DriverStatus statusOf(Driver d) {
    if (d.blocked) return DriverStatus.blocked;
    if (!d.online) return DriverStatus.offline;
    if (activeRideForDriver(d.id) != null) return DriverStatus.onTrip;
    return DriverStatus.available;
  }

  /// The customer's current open ride, if any.
  Ride? get activeCustomerRide {
    for (final r in rides) {
      if (r.customerId == customerId && r.status.isOpen) return r;
    }
    return null;
  }

  /// A just-completed ride waiting for a rating.
  Ride? get ratingPendingRide {
    for (final r in rides) {
      if (r.customerId == customerId && r.status == RideStatus.completed && r.rating == null) {
        return r;
      }
    }
    return null;
  }

  List<Ride> get customerRides => rides.where((r) => r.customerId == customerId).toList();

  Ride? activeRideForDriver(String driverId) {
    for (final r in rides) {
      if (r.driverId == driverId && r.status.isLive) return r;
    }
    return null;
  }

  List<Ride> offeredTo(String driverId) =>
      rides.where((r) => r.status == RideStatus.assigned && r.driverId == driverId).toList();

  List<Ride> get openPool => rides.where((r) => r.status == RideStatus.requested).toList();

  List<Ride> ridesOfDriver(String driverId) =>
      rides.where((r) => r.driverId == driverId && r.status == RideStatus.completed).toList();

  double etaMinutes(Ride r) {
    if (r.activePath.length < 2) return r.legMinutes;
    final frac = 1 - r.simIndex / (r.activePath.length - 1);
    return math.max(1, (r.legMinutes * frac).ceilToDouble());
  }

  bool atDestination(Ride r) =>
      r.status == RideStatus.inTrip &&
      r.activePath.length > 1 &&
      r.simIndex >= r.activePath.length - 1;

  // ------------------------------------------------------------------ stats

  int get totalRides => rides.length;
  int get pendingCount => rides.where((r) => r.status == RideStatus.requested).length;
  int get activeCount =>
      rides.where((r) => r.status.isOpen && r.status != RideStatus.requested).length;
  int get completedCount => rides.where((r) => r.status == RideStatus.completed).length;
  int get cancelledCount => rides.where((r) => r.status == RideStatus.cancelled).length;
  double get revenue =>
      rides.where((r) => r.status == RideStatus.completed).fold(0.0, (s, r) => s + r.fare);
  double get commission => revenue * Brand.commission;
  int get onlineDrivers =>
      drivers.where((d) => !d.blocked && d.online).length;

  // ---------------------------------------------------------------- actions

  Ride createRide({
    required Place pickup,
    required Place dropoff,
    required VehicleType vehicle,
    required RouteResult route,
    required String payment,
  }) {
    final r = Ride(
      id: 'WY-${_seq++}',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      pickup: pickup,
      dropoff: dropoff,
      vehicle: vehicle,
      distanceKm: route.km,
      durationMin: route.minutes,
      fare: vehicle.fareFor(route.km, route.minutes),
      payment: payment,
      createdAt: DateTime.now(),
      path: route.points,
    );
    r.log('Ride requested by $customerName');
    rides.insert(0, r);
    notifyListeners();
    return r;
  }

  void cancelRide(String rideId, String by) {
    final r = rideById(rideId);
    if (r == null || !r.status.isOpen) return;
    if (r.status == RideStatus.inTrip) return;
    r.status = RideStatus.cancelled;
    r.log('Cancelled by $by');
    notifyListeners();
  }

  /// Admin assigns (or re-assigns) a ride to a driver. The driver then has to
  /// confirm it from the driver dashboard.
  void assignRide(String rideId, String driverId) {
    final r = rideById(rideId);
    if (r == null) return;
    if (r.status != RideStatus.requested && r.status != RideStatus.assigned) return;
    r.driverId = driverId;
    r.status = RideStatus.assigned;
    r.log('Admin assigned ride to ${driverById(driverId).name}');
    notifyListeners();
  }

  /// Driver accepts an offered ride, or picks one from the open pool.
  Future<void> acceptRide(String rideId, String driverId) async {
    final r = rideById(rideId);
    final d = driverById(driverId);
    if (r == null) return;
    final pickable = r.status == RideStatus.requested ||
        (r.status == RideStatus.assigned && r.driverId == driverId);
    if (!pickable || !d.online || d.blocked || activeRideForDriver(driverId) != null) return;

    final picked = r.status == RideStatus.requested;
    r.driverId = driverId;
    r.status = RideStatus.accepted;
    r.activePath = [];
    r.simIndex = 0;
    r.legMinutes = 3;
    r.log(picked ? '${d.name} picked the ride' : '${d.name} accepted the ride');
    notifyListeners();

    final route = await RoutingService.route(d.position, r.pickup.point);
    if (r.status == RideStatus.accepted && r.driverId == driverId) {
      r.activePath = route.points;
      r.simIndex = 0;
      r.legMinutes = route.minutes;
      notifyListeners();
    }
  }

  void declineRide(String rideId, String driverId) {
    final r = rideById(rideId);
    if (r == null || r.status != RideStatus.assigned || r.driverId != driverId) return;
    r.log('${driverById(driverId).name} declined, back to dispatch');
    r.driverId = null;
    r.status = RideStatus.requested;
    notifyListeners();
  }

  /// Returns false if the OTP is wrong.
  bool startTrip(String rideId, String otp) {
    final r = rideById(rideId);
    if (r == null || r.status != RideStatus.arrived) return false;
    if (otp.trim() != r.otp) return false;
    r.status = RideStatus.inTrip;
    r.activePath = r.path;
    r.simIndex = 0;
    r.legMinutes = r.durationMin;
    r.log('Trip started');
    notifyListeners();
    return true;
  }

  void completeTrip(String rideId) {
    final r = rideById(rideId);
    if (r == null || !atDestination(r)) return;
    final d = driverById(r.driverId!);
    r.status = RideStatus.completed;
    d.trips += 1;
    d.earnings += r.fare * (1 - Brand.commission);
    r.log('Trip completed, ${r.payment} payment of ${Brand.currency} ${r.fare.round()}');
    notifyListeners();
  }

  void rateRide(String rideId, int stars) {
    final r = rideById(rideId);
    if (r == null) return;
    r.rating = stars;
    if (stars > 0 && r.driverId != null) {
      final d = driverById(r.driverId!);
      d.rating = (d.rating * d.ratingCount + stars) / (d.ratingCount + 1);
      d.ratingCount += 1;
    }
    notifyListeners();
  }

  void setDriverOnline(String driverId, bool online) {
    final d = driverById(driverId);
    if (activeRideForDriver(driverId) != null && !online) return;
    d.online = online;
    notifyListeners();
  }

  void toggleBlock(String driverId) {
    final d = driverById(driverId);
    d.blocked = !d.blocked;
    notifyListeners();
  }

  // ------------------------------------------------------------- simulation

  /// Moves drivers along their route so every dashboard sees live tracking.
  /// A real backend would push GPS updates instead.
  void _tick(Timer _) {
    var changed = false;
    for (final r in rides) {
      if (r.status != RideStatus.accepted && r.status != RideStatus.inTrip) continue;
      if (r.activePath.length < 2 || r.driverId == null) continue;
      if (r.simIndex >= r.activePath.length - 1) continue;
      final d = driverById(r.driverId!);
      final step = math.max(1, r.activePath.length ~/ 30);
      r.simIndex = math.min(r.simIndex + step, r.activePath.length - 1);
      d.position = r.activePath[r.simIndex];
      changed = true;
      if (r.simIndex >= r.activePath.length - 1 && r.status == RideStatus.accepted) {
        r.status = RideStatus.arrived;
        r.log('Driver arrived at pickup');
      }
    }
    if (changed) notifyListeners();
  }

  // ------------------------------------------------------------------- seed

  static const places = <Place>[
    Place(name: 'Times Square', address: 'Manhattan, New York, NY', point: LatLng(40.7580, -73.9855)),
    Place(name: 'JFK Airport', address: 'Queens, New York, NY', point: LatLng(40.6413, -73.7781)),
    Place(name: 'Central Park', address: 'Manhattan, New York, NY', point: LatLng(40.7812, -73.9665)),
    Place(name: 'Wall Street', address: 'Financial District, New York, NY', point: LatLng(40.7060, -74.0088)),
    Place(name: 'Brooklyn Bridge', address: 'New York, NY', point: LatLng(40.7061, -73.9969)),
    Place(name: 'SoHo', address: 'Manhattan, New York, NY', point: LatLng(40.7233, -74.0030)),
    Place(name: 'LaGuardia Airport', address: 'Queens, New York, NY', point: LatLng(40.7769, -73.8740)),
    Place(name: 'The Plaza Hotel', address: 'Fifth Avenue, New York, NY', point: LatLng(40.7645, -73.9744)),
    Place(name: 'Newark Airport', address: 'Newark, NJ', point: LatLng(40.6895, -74.1745)),
  ];

  void _seed() {
    const c = Brand.cityCenter;
    LatLng near(double dLat, double dLng) => LatLng(c.latitude + dLat, c.longitude + dLng);

    drivers.addAll([
      Driver(id: 'd1', name: 'James Carter', phone: '+1 212 555 0101', vehicle: VehicleType.mini,
          model: 'BMW 5 Series', plate: 'NYC-4821', position: near(0.004, -0.006), rating: 4.9, trips: 812, earnings: 18450),
      Driver(id: 'd2', name: 'Michael Brooks', phone: '+1 917 555 0102', vehicle: VehicleType.mini,
          model: 'Mercedes-Benz E-Class', plate: 'NYC-9087', position: near(-0.012, 0.010), rating: 4.8, trips: 641, earnings: 28430),
      Driver(id: 'd3', name: 'Daniel Reed', phone: '+1 646 555 0103', vehicle: VehicleType.mini,
          model: 'Tesla Model 3', plate: 'NYC-1180', position: near(0.020, 0.004), rating: 4.7, trips: 498, earnings: 22100),
      Driver(id: 'd4', name: 'Anthony Hayes', phone: '+1 718 555 0104', vehicle: VehicleType.mini,
          model: 'Cadillac XT6', plate: 'NYC-3345', position: near(-0.006, -0.018), rating: 4.9, trips: 550, earnings: 31900),
      Driver(id: 'd5', name: 'Robert Wilson', phone: '+1 917 555 0105', vehicle: VehicleType.mini,
          model: 'Audi A6', plate: 'NYC-7712', position: near(0.010, 0.020), rating: 4.8, trips: 476, earnings: 24600, online: false),
      Driver(id: 'd6', name: 'Christopher Lee', phone: '+1 347 555 0106', vehicle: VehicleType.mini,
          model: 'Volvo S90', plate: 'NYC-2468', position: near(-0.020, -0.004), rating: 4.9, trips: 789, earnings: 36200),
    ]);

    Ride seeded(String id, String cName, String phone, Place a, Place b, VehicleType v,
        double km, double mins, RideStatus st, {String? driver, int? rating, int minsAgo = 0}) {
      final r = Ride(
        id: id, customerId: cName == customerName ? customerId : 'x_$id',
        customerName: cName, customerPhone: phone,
        pickup: a, dropoff: b, vehicle: v, distanceKm: km, durationMin: mins,
        fare: v.fareFor(km, mins), payment: 'Cash',
        createdAt: DateTime.now().subtract(Duration(minutes: minsAgo)),
        path: RoutingService.straightLine(a.point, b.point),
        status: st, driverId: driver,
      );
      final t = r.createdAt;
      r.log('Ride requested by $cName', t);
      if (driver != null) r.log('Admin assigned ride to ${driverById(driver).name}', t.add(const Duration(minutes: 1)));
      if (st == RideStatus.completed) {
        r.log('Trip started', t.add(const Duration(minutes: 8)));
        r.log('Trip completed, Cash payment of ${Brand.currency} ${r.fare.round()}', t.add(Duration(minutes: 8 + mins.round())));
        r.rating = rating;
      }
      return r;
    }

    rides.addAll([
      seeded('WY-1005', 'Alex Morgan', '+1 917 555 0121', places[1], places[0], VehicleType.mini,
          15.2, 38, RideStatus.requested, minsAgo: 4),
      seeded('WY-1004', 'Olivia Bennett', '+1 646 555 0122', places[2], places[7], VehicleType.mini,
          3.8, 18, RideStatus.requested, minsAgo: 2),
      seeded('WY-1003', 'Sara Khan', '+1 212 555 0148', places[3], places[6], VehicleType.mini,
          12.5, 31, RideStatus.completed, driver: 'd1', rating: 5, minsAgo: 1500),
      seeded('WY-1002', 'Ethan Cole', '+1 917 555 0124', places[4], places[8], VehicleType.mini,
          14.1, 35, RideStatus.completed, driver: 'd3', rating: 4, minsAgo: 2900),
      seeded('WY-1001', 'Mia Thompson', '+1 718 555 0125', places[5], places[0], VehicleType.mini,
          4.7, 22, RideStatus.cancelled, minsAgo: 4300),
    ]);    rides.last.log('Cancelled by customer', rides.last.createdAt.add(const Duration(minutes: 3)));
  }
}
