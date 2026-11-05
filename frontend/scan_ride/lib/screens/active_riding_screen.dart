import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../models/ride.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../widgets/info_tile.dart';

/// หน้า 7 · Active Riding
/// แสดงเวลาที่ใช้งาน / แบตเตอรี่ / สถานีต้นทาง / สถานีใกล้เคียง
/// และปุ่ม Return vehicle กับ Report a problem
class ActiveRidingScreen extends StatefulWidget {
  const ActiveRidingScreen({super.key});

  @override
  State<ActiveRidingScreen> createState() => _ActiveRidingScreenState();
}

class _ActiveRidingScreenState extends State<ActiveRidingScreen> {
  late final Future<StationInfo> _nearby;

  @override
  void initState() {
    super.initState();
    _nearby = ApiService.instance.getNearbyStation(); // ถามครั้งเดียวตอนเปิดหน้า
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 1104 วินาที -> "00:18:24"
  static String _clock(Duration d) =>
      '${_two(d.inHours)}:${_two(d.inMinutes.remainder(60))}:${_two(d.inSeconds.remainder(60))}';

  @override
  Widget build(BuildContext context) {
    // watch = RideProvider เปลี่ยนค่า (ทุก 1 วินาที) หน้านี้จะวาดใหม่เอง
    final rp = context.watch<RideProvider>();
    final ride = rp.ride;

    if (ride == null) return const _NoActiveRide();

    final started = ride.startedAt;
    final lowBattery = rp.battery < 20;

    // PopScope(canPop: false) = ล็อกปุ่มย้อนกลับ กันออกจากหน้าระหว่างขี่
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Column(
          children: [
            // ---------- ส่วนหัวสีแดง: ชื่อรถ + เวลา ----------
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 26),
              decoration: const BoxDecoration(
                color: AppColors.crimson,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Text('Riding · ${ride.vehicle.id}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    _clock(rp.elapsed),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Started ${_two(started.hour)}:${_two(started.minute)} at ${ride.fromStation}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            // ---------- การ์ดข้อมูล ----------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  InfoTile(
                    icon: Icons.battery_charging_full,
                    title: 'Battery ${rp.battery}%',
                    trailing: lowBattery
                        ? const StatusChip(label: 'Low', positive: false)
                        : null,
                    bottom: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: rp.battery / 100,
                        minHeight: 7,
                        color: lowBattery ? AppColors.crimson : AppColors.gold,
                        backgroundColor: AppColors.goldSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoTile(
                    icon: Icons.place_outlined,
                    title: 'From: ${ride.fromStation}',
                    subtitle: 'Choose a return station when ready',
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<StationInfo>(
                    future: _nearby,
                    builder: (context, snap) {
                      final s = snap.data;
                      final text = snap.hasError
                          ? 'Unable to load stations'
                          : s == null
                              ? 'Looking for stations…'
                              : '${s.name} · ${s.freeDocks} free docks';
                      return InfoTile(
                        icon: Icons.apartment,
                        title: 'Nearby station',
                        subtitle: text,
                      );
                    },
                  ),
                ],
              ),
            ),

            // ---------- ปุ่มด้านล่าง ----------
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    // ไปหน้า Choose return station (เพื่อนทำ)
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.returnStation),
                    child: const Text('Return vehicle'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    // ไปหน้า Report a problem (เพื่อนทำ) พร้อมส่งรหัสรถไปด้วย
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.report,
                      arguments: ride.vehicle.id,
                    ),
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: const Text('Report a problem'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// กรณีเปิดหน้านี้ทั้งที่ยังไม่ได้ยืมรถ (เช่น Hot restart ตอนพัฒนา)
class _NoActiveRide extends StatelessWidget {
  const _NoActiveRide();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pedal_bike, size: 56, color: AppColors.gold),
            const SizedBox(height: 12),
            const Text('No active ride', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.scan),
                child: const Text('Scan QR code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
