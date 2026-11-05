import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ride.dart';

/// เก็บสถานะ "กำลังขี่อยู่" ของทั้งแอป + ตัวจับเวลา
/// หน้าอื่นอ่านได้ผ่าน context.watch<RideProvider>() เช่น
///   - Home: isRiding       (แสดงเลข Borrowed)
///   - Choose return station: ride, elapsedMinutes
///   - เมื่อคืนสำเร็จ: endRide()
class RideProvider extends ChangeNotifier {
  Ride? _ride;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  int _battery = 0;

  Ride? get ride => _ride;
  bool get isRiding => _ride != null;
  Duration get elapsed => _elapsed;
  int get elapsedMinutes => _elapsed.inMinutes;
  int get battery => _battery;

  /// เรียกตอนกด Confirm borrow สำเร็จ
  void startRide(Ride ride) {
    _ticker?.cancel();
    _ride = ride;
    _battery = ride.vehicle.battery;
    _elapsed = Duration.zero;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void _tick() {
    final ride = _ride;
    if (ride == null) return;
    // คำนวณจาก "เวลาเริ่ม" เสมอ (ไม่ใช่นับ +1) เวลาจึงไม่เพี้ยนแม้เปลี่ยนหน้า
    final diff = DateTime.now().difference(ride.startedAt);
    _elapsed = diff.isNegative ? Duration.zero : diff;
    // จำลองแบตลด 1% ทุก 150 วินาที (ถ้ามี backend จริงให้ดึงค่าแบตมาแทน)
    _battery =
        (ride.vehicle.battery - _elapsed.inSeconds ~/ 150).clamp(0, 100).toInt();
    notifyListeners();
  }

  /// เรียกเมื่อคืนรถสำเร็จ (หน้า Choose return station ของเพื่อนเรียกใช้)
  void endRide() {
    _ticker?.cancel();
    _ticker = null;
    _ride = null;
    _elapsed = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
