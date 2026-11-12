// ทดสอบกฎหลักของระบบ (ตรงกับ stored procedure ในฐานข้อมูล) – รันด้วย: flutter test
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoride_app/data/app_store.dart';
import 'package:ecoride_app/data/models.dart';

void main() {
  test('login → borrow → return → top up', () {
    final s = AppStore.instance;

    expect(s.login('admin', 'password123'), isNull); // admin ล็อกอินหน้าเดียวกันได้
    expect(s.me!.isAdmin, isTrue);
    s.logout();
    expect(s.login('somchai.j', 'wrong'), isNotNull);
    expect(s.login('somchai.j', 'password123'), isNull);
    final before = s.me!.creditBalance;

    // ยืม EB-012 (แบต 79%) – หักเงิน 100 บาท
    final bike = s.vehicleByCode('EB-012')!;
    final (ride, err) = s.borrow(bike, s.defaultPlan);
    expect(err, isNull);
    expect(ride, isNotNull);
    expect(s.me!.creditBalance, before - 100);

    // ยืมซ้ำไม่ได้ (1 คน มี ride ค้างได้ 1 คัน)
    final (_, err2) = s.borrow(s.vehicleByCode('EB-004')!, s.defaultPlan);
    expect(err2, isNotNull);

    // ยืมรถแบตต่ำกว่า 20% ไม่ได้
    expect(s.canBorrowVehicle(s.vehicleByCode('ES-031')!), isFalse);

    // คืนได้เฉพาะสถานีที่ยืมมา
    final start = s.stationById(ride!.startStationId);
    final other = s.stations.firstWhere((x) => x.stationId != start.stationId);
    expect(s.returnVehicle(ride, other), isNotNull);
    expect(s.returnVehicle(ride, start), isNull);
    expect(s.activeRide, isNull);

    // เติมเงิน
    final t = s.createTopup(200);
    expect(s.confirmTopup(t), isNull);
    expect(s.me!.creditBalance, before - 100 + 200);
  });

  test('forgot username + reset password ต้องใช้ student ID', () {
    final s = AppStore.instance;
    final (name, err) = s.findUsername(studentId: '6731501118', fullName: 'somchai jaidee');
    expect(err, isNull);
    expect(name, 'somchai.j');

    // student ID ผิด → เปลี่ยนรหัสไม่ได้
    expect(
        s.resetPassword(
            username: 'somchai.j',
            studentId: '0000000000',
            fullName: 'Somchai Jaidee',
            password: 'newpass123',
            confirm: 'newpass123'),
        isNotNull);
    // ครบ 3 อย่าง → เปลี่ยนได้ และล็อกอินด้วยรหัสใหม่ได้
    expect(
        s.resetPassword(
            username: 'somchai.j',
            studentId: '6731501118',
            fullName: 'Somchai Jaidee',
            password: 'newpass123',
            confirm: 'newpass123'),
        isNull);
    expect(s.login('somchai.j', 'newpass123'), isNull);
  });

  test('เลือกอวาตาร์สำเร็จรูป', () {
    final s = AppStore.instance;
    s.setPresetAvatar(5);
    expect(s.avatarId, 5);
    s.setAvatar(null); // ลบ
    expect(s.hasAvatar, isFalse);
  });

  test('เรียกเจ้าหน้าที่ระหว่างยืม + feedback', () {
    final s = AppStore.instance;
    final (ride, err) = s.borrow(s.vehicleByCode('EB-015')!, s.defaultPlan);
    expect(err, isNull);

    // ต้องบอกตำแหน่ง
    expect(s.requestHelp(ride: ride!, type: HelpType.flatTyre, location: '').$2, isNotNull);
    final (no, err2) =
        s.requestHelp(ride: ride, type: HelpType.flatTyre, location: 'Building 2');
    expect(err2, isNull);
    expect(no, isNotNull);

    expect(s.submitFeedback(topic: FeedbackTopic.appBug, message: 'hi'), isNotNull);
    expect(s.submitFeedback(topic: FeedbackTopic.appBug, message: 'Map page is slow'), isNull);

    expect(s.returnVehicle(ride, s.stationById(ride.startStationId)), isNull);
  });

  test('แบต: รถจอดชาร์จ + รถแบตต่ำรอกี่นาที', () {
    final s = AppStore.instance;
    final low = s.vehicleByCode('ES-031')!; // 12%
    expect(s.isCharging(low), isTrue);
    expect(s.minutesUntilReady(low), 15); // (20-12) / 32%ต่อชม. ≈ 15 นาที
    // ขี่ 1 ชม.: scooter ~9 กม. → ใช้แบต ~27%, bike ~7.2 กม. → ~11%
    final km = s.estimatedKm(s.vehicleByCode('EB-005')!, const Duration(hours: 1));
    expect(km, closeTo(7.2, 0.01));
    s.logout(); // หยุดตัวจับเวลา
  });

  test('ฝั่ง admin เห็นข้อมูลชุดเดียวกับผู้ใช้', () {
    final s = AppStore.instance;
    expect(s.login('admin', 'password123'), isNull);

    // คำขอ Need help? ที่ผู้ใช้ส่งในเทสต์ก่อนหน้า ต้องโผล่ในรายการด่วนของแอดมิน
    expect(s.urgentOpen.length, greaterThanOrEqualTo(2));
    expect(s.revenueThisMonth, greaterThanOrEqualTo(100));

    // ยืนยัน top-up ที่ค้าง → เครดิตเพิ่ม, ยืนยันซ้ำไม่ได้
    final t = s.pendingTopups.first;
    final u = s.userById(t.userId);
    final before = u.creditBalance;
    expect(s.confirmTopup(t), isNull);
    expect(u.creditBalance, before + t.amount);
    expect(s.confirmTopup(t), isNotNull);

    // รถที่มีคนยืม ส่งซ่อมไม่ได้ / ระงับบัญชีคนที่ยังยืมอยู่ไม่ได้
    final inUse = s.vehicles.firstWhere((v) => v.status == VehicleStatus.inUse);
    expect(s.setMaintenance(inUse, true), isNotNull);
    expect(s.setUserActive(s.userById(s.openRideOf(inUse)!.userId), false), isNotNull);

    // เพิ่มรถ: รหัสซ้ำไม่ได้
    final eb = s.types.firstWhere((x) => x.isBike);
    expect(s.addVehicle(type: eb, number: '12', station: s.allStations.first), isNotNull);
    expect(s.addVehicle(type: eb, number: '30', station: s.allStations.first), isNull);

    // ปิดสถานี → ผู้ใช้มองไม่เห็นสถานีนั้น
    expect(s.saveStation(s.allStations.last, name: 'Building 3', docks: 10, active: false),
        isNotNull); // Malee ยังยืมรถจาก Building 3 อยู่
    final st = s.allStations.first;
    expect(s.saveStation(st, name: st.name, docks: st.totalDocks, active: false), isNull);
    expect(s.stations.contains(st), isFalse);
    s.logout();
  });
}
