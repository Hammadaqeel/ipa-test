import 'package:flutter/material.dart';

import '../core/brand.dart';
import 'admin/admin_home.dart';
import 'customer/customer_home.dart';
import 'driver/driver_home.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 12, 18, 28 + bottom),
          children: [
            // Compact header: deliberately much shorter than the previous version.
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    Brand.name,
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEDED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'USA',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Your ride,\nwhen you need it.',
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 34,
                height: 1.02,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Simple booking. Reliable drivers. Comfortable rides.',
              style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            _PrimaryRideCard(
              onTap: () => _open(context, const CustomerHome()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SmallRoleCard(
                    icon: Icons.directions_car_filled_rounded,
                    title: 'Driver',
                    onTap: () => _open(context, const DriverHome()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SmallRoleCard(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Admin',
                    onTap: () => _open(context, const AdminHome()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Center(
              child: Text(
                'NEW YORK  •  UNITED STATES',
                style: TextStyle(
                  color: Color(0xFF969696),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryRideCard extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryRideCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 18, 16, 17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.near_me_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Book a ride', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Set a destination and choose your ride.', style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallRoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SmallRoleCard({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE2E2E2)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: const Color(0xFF222222), size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF888888), size: 19),
            ],
          ),
        ),
      ),
    );
  }
}
