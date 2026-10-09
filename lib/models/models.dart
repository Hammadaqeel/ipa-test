import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/brand.dart';

enum VehicleType { bike, rickshaw, mini, comfort }

extension VehicleInfo on VehicleType {
  String get label {
    switch (this) {
      case VehicleType.bike:
        return 'Wayo Select';
      case VehicleType.rickshaw:
        return 'Wayo Executive';
      case VehicleType.mini:
        return 'Wayo Premium';
      case VehicleType.comfort:
        return 'Wayo Black';
    }
  }

  String get tagline {
    switch (this) {
      case VehicleType.bike:
        return 'Premium everyday ride';
      case VehicleType.rickshaw:
        return 'Executive comfort';
      case VehicleType.mini:
        return 'Upscale sedan';
      case VehicleType.comfort:
        return 'Luxury sedan, priority service';
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleType.bike:
      case VehicleType.rickshaw:
      case VehicleType.mini:
      case VehicleType.comfort:
        return Icons.directions_car_filled;
    }
  }

  int get seats {
    switch (this) {
      case VehicleType.bike:
      case VehicleType.rickshaw:
      case VehicleType.mini:
      case VehicleType.comfort:
        return 4;
    }
  }

  double get base {
    switch (this) {
      case VehicleType.bike:
        return 9;
      case VehicleType.rickshaw:
        return 14;
      case VehicleType.mini:
        return 18;
      case VehicleType.comfort:
        return 28;
    }
  }

  double get perKm {
    switch (this) {
      case VehicleType.bike:
        return 2.1;
      case VehicleType.rickshaw:
        return 3.0;
      case VehicleType.mini:
        return 3.2;
      case VehicleType.comfort:
        return 4.5;
    }
  }

  double get perMin {
    switch (this) {
      case VehicleType.bike:
        return 0.45;
      case VehicleType.rickshaw:
        return 0.65;
      case VehicleType.mini:
        return 0.75;
      case VehicleType.comfort:
        return 1.0;
    }
  }

  double fareFor(double km, double minutes) {
    final raw = base + perKm * km + perMin * minutes;
    return (raw / 10).round() * 10.0;
  }
}

class Place {
  final String name;
  final String address;
  final LatLng point;
  const Place({required this.name, required this.address, required this.point});
}

enum RideStatus { requested, assigned, accepted, arrived, inTrip, completed, cancelled }

extension RideStatusInfo on RideStatus {
  String get label {
    switch (this) {
      case RideStatus.requested:
        return 'Finding driver';
      case RideStatus.assigned:
        return 'Awaiting driver';
      case RideStatus.accepted:
        return 'Driver on the way';
      case RideStatus.arrived:
        return 'Driver arrived';
      case RideStatus.inTrip:
        return 'On trip';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case RideStatus.requested:
        return AppColors.accent;
      case RideStatus.assigned:
        return const Color(0xFFE08A00);
      case RideStatus.accepted:
        return AppColors.info;
      case RideStatus.arrived:
        return const Color(0xFF7B5BD6);
      case RideStatus.inTrip:
        return AppColors.primary;
      case RideStatus.completed:
        return AppColors.ok;
      case RideStatus.cancelled:
        return AppColors.danger;
    }
  }

  bool get isOpen => this != RideStatus.completed && this != RideStatus.cancelled;
  bool get isLive =>
      this == RideStatus.accepted || this == RideStatus.arrived || this == RideStatus.inTrip;
}

class RideEvent {
  final DateTime time;
  final String text;
  RideEvent(this.time, this.text);
}

class Ride {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final Place pickup;
  final Place dropoff;
  final VehicleType vehicle;
  final double distanceKm;
  final double durationMin;
  final double fare;
  final String payment;
  final DateTime createdAt;
  final String otp;

  /// Planned route pickup -> dropoff.
  List<LatLng> path;
  RideStatus status;
  String? driverId;
  int? rating; // null = not rated yet, 0 = skipped

  // Live simulation state.
  List<LatLng> activePath = [];
  int simIndex = 0;
  double legMinutes = 0;

  final List<RideEvent> events = [];

  Ride({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.pickup,
    required this.dropoff,
    required this.vehicle,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.payment,
    required this.createdAt,
    required this.path,
    this.status = RideStatus.requested,
    this.driverId,
  }) : otp = (1000 + math.Random().nextInt(9000)).toString();

  void log(String text, [DateTime? at]) => events.add(RideEvent(at ?? DateTime.now(), text));
}

enum DriverStatus { available, onTrip, offline, blocked }

extension DriverStatusInfo on DriverStatus {
  String get label {
    switch (this) {
      case DriverStatus.available:
        return 'Available';
      case DriverStatus.onTrip:
        return 'On trip';
      case DriverStatus.offline:
        return 'Offline';
      case DriverStatus.blocked:
        return 'Blocked';
    }
  }

  Color get color {
    switch (this) {
      case DriverStatus.available:
        return AppColors.ok;
      case DriverStatus.onTrip:
        return AppColors.info;
      case DriverStatus.offline:
        return AppColors.muted;
      case DriverStatus.blocked:
        return AppColors.danger;
    }
  }
}

class Driver {
  final String id;
  final String name;
  final String phone;
  final VehicleType vehicle;
  final String model;
  final String plate;
  double rating;
  int ratingCount;
  LatLng position;
  bool online;
  bool blocked;
  int trips;
  double earnings;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.model,
    required this.plate,
    required this.position,
    this.rating = 4.8,
    this.ratingCount = 40,
    this.online = true,
    this.blocked = false,
    this.trips = 0,
    this.earnings = 0,
  });

  String get initials {
    final parts = name.split(' ');
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }
}
