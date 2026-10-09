import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wayo/main.dart';
import 'package:wayo/models/models.dart';
import 'package:wayo/state/app_state.dart';

void main() {
  testWidgets('role picker shows the three dashboards', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(simulate: false),
        child: const WayoApp(),
      ),
    );
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  test('admin can assign a ride and the driver can run it to completion', () {
    final app = AppState(simulate: false);
    final ride = app.rides.firstWhere((r) => r.status == RideStatus.requested);
    final driver = app.drivers.firstWhere((d) => d.online);

    app.assignRide(ride.id, driver.id);
    expect(ride.status, RideStatus.assigned);
    expect(app.offeredTo(driver.id), contains(ride));

    app.declineRide(ride.id, driver.id);
    expect(ride.status, RideStatus.requested);

    // Wrong PIN never starts a trip.
    ride.status = RideStatus.arrived;
    ride.driverId = driver.id;
    expect(app.startTrip(ride.id, 'nope'), isFalse);
    expect(app.startTrip(ride.id, ride.otp), isTrue);
    expect(ride.status, RideStatus.inTrip);

    ride.simIndex = ride.activePath.length - 1;
    app.completeTrip(ride.id);
    expect(ride.status, RideStatus.completed);
    expect(driver.trips, greaterThan(0));
  });
}
