// Tests for AppStore + ApiClient without starting the real backend: uses the fake backend in fake_backend.dart
// (replies with JSON shaped like the real API) – run with: flutter test
// The real business rules (deduct credit, return vehicle, etc.) are tested on the backend side with jest (backend/tests)
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ecoride_app/data/api_client.dart';
import 'package:ecoride_app/data/models.dart';

import 'fake_backend.dart';

void main() {
  group('ApiClient', () {
    test('แนบ token และอ่านข้อความ error จาก backend', () async {
      final b = FakeBackend();
      b.routes['GET /api/me'] = (r) => r.headers['Authorization'] == 'Bearer abc' ? {'ok': true} : FakeErr(401, 'Please log in');

      final api = ApiClient(client: b.client, baseUrl: 'http://test');

      await expectLater(api.get('/me'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Please log in')));
      api.token = 'abc';
      expect(await api.get('/me'), {'ok': true});
    });

    test('ติดต่อ server ไม่ได้ → ข้อความที่อ่านรู้เรื่อง', () async {
      final api = ApiClient(client: MockClient((_) async => throw http.ClientException('down')), baseUrl: 'http://test');
      await expectLater(
          api.get('/me'), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Cannot reach the server'))));
    });

    test('เดา MIME ของรูปจาก byte แรก', () {
      expect(sniffImageMime(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0])), 'image/png');
      expect(sniffImageMime(Uint8List.fromList([0xFF, 0xD8, 0xFF])), 'image/jpeg');
      expect(sniffImageMime(Uint8List.fromList([1, 2, 3])), 'application/octet-stream');
    });
  });

  group('นักศึกษา', () {
    test('login ผิด → ข้อความจาก backend, ถูก → โหลดสถานี/รถมาใส่ cache', () async {
      final s = storeFor(studentBackend());
      expect(await s.login('somchai.j', 'wrong'), 'Wrong username or password');
      expect(s.me, isNull);

      expect(await s.login(' somchai.j ', 'password123'), isNull);
      expect(s.me!.username, 'somchai.j');
      expect(s.me!.isAdmin, isFalse);
      expect(s.stations.map((x) => x.name), ['Building 1', 'Building 2', 'Building 3']);
      expect(s.defaultPlan.price, 100);

      expect(s.vehiclesAt(1).map((v) => v.code), ['ES-016', 'EB-012', 'EB-015', 'ES-031']);
      final a = s.availability(s.stationById(1));
      expect((a.readyBikes, a.readyScooters, a.docked, a.freeDocks, a.full), (2, 1, 4, 6, false));
      expect(s.myRides.single.status, RideStatus.returned); // sample history has 1 ride
      expect(s.activeRide, isNull);
      expect(s.vehicleByCode(' es-031 ')!.vehicleId, 3);
    });

    test('แบต: รถจอดชาร์จ + รถแบตต่ำรอกี่นาที', () async {
      final s = storeFor(studentBackend());
      await s.login('somchai.j', 'password123');
      final low = s.vehicleByCode('ES-031')!;
      expect(s.canBorrowVehicle(low), isFalse);
      expect(s.isCharging(low), isTrue);
      expect(s.minutesUntilReady(low), 15);
      expect(s.estimatedKm(s.vehicleByCode('EB-012')!, const Duration(hours: 1)), closeTo(7.2, 0.01));
      expect(s.canBorrowVehicle(s.vehicleByCode('EB-012')!), isTrue);
    });

    test('borrow: backend ปฏิเสธ → ได้ข้อความ error เดิมของแอป', () async {
      final b = studentBackend()..routes['POST /api/rides'] = (_) => FakeErr(409, 'Not enough credit. Please top up first.');
      final s = storeFor(b);
      await s.login('somchai.j', 'password123');
      final (ride, err) = await s.borrow(s.vehicleByCode('EB-012')!, s.defaultPlan);
      expect(ride, isNull);
      expect(err, 'Not enough credit. Please top up first.');
    });

    test('borrow → return: ส่ง vehicle_id/plan_id และ station_id ถูกต้อง แล้ว refresh', () async {
      final b = studentBackend();
      var rides = <Object?>[];
      b.routes['GET /api/rides'] = (_) => rides;
      b.routes['POST /api/rides'] = (_) {
        rides = [rideJson()];
        return {'ride': rideJson(), 'user': userJson(1, 'somchai.j', credit: 50)};
      };
      b.routes['POST /api/rides/7/return'] = (_) {
        rides = [rideJson(status: 'returned')];
        return rideJson(status: 'returned');
      };
      final s = storeFor(b);
      await s.login('somchai.j', 'password123');

      final (ride, err) = await s.borrow(s.vehicleByCode('EB-012')!, s.defaultPlan);
      expect(err, isNull);
      expect(ride!.rideId, 7);
      expect(jsonDecode(b.lastCall('POST', '/api/rides')!.body), {'vehicle_id': 1, 'plan_id': 1});
      expect(s.activeRide?.rideId, 7);

      expect(await s.returnVehicle(ride, s.stationById(1)), isNull);
      expect(jsonDecode(b.lastCall('POST', '/api/rides/7/return')!.body), {'station_id': 1});
      expect(s.activeRide, isNull);
      expect(s.myRides.single.status, RideStatus.returned);
    });

    test('Need help?: ส่งชนิด/ตำแหน่ง และได้เลขคำขอกลับมา', () async {
      final b = studentBackend()
        ..routes['POST /api/rides/7/help'] = (_) => {
              'report_id': 11,
              'user_id': 1,
              'vehicle_id': 1,
              'ride_id': 7,
              'category': 'brakes_wheels',
              'details': '[URGENT] Flat tyre · at: Near the library',
              'status': 'open',
              'created_at': '2026-11-11 09:05:00',
              'resolved_at': null,
            };
      final s = storeFor(b);
      await s.login('somchai.j', 'password123');
      final ride = Ride.fromJson(rideJson());
      final (no, err) = await s.requestHelp(ride: ride, type: HelpType.flatTyre, location: 'Near the library');
      expect((no, err), (11, null));
      expect(jsonDecode(b.lastCall('POST', '/api/rides/7/help')!.body), containsPair('type', 'flatTyre'));
    });

    test('เติมเงิน: สร้างรายการแล้วยืนยัน (path ของนักศึกษา)', () async {
      final topup = {
        'topup_id': 3,
        'user_id': 1,
        'amount': 200,
        'payment_method': 'qr',
        'reference_code': 'ECO1-ABC',
        'status': 'pending',
        'created_at': '2026-11-11 10:00:00',
        'paid_at': null,
      };
      final b = studentBackend()
        ..routes['POST /api/topups'] = ((_) => topup)
        ..routes['POST /api/topups/3/confirm'] =
            ((_) => {'topup': {...topup, 'status': 'paid', 'paid_at': '2026-11-11 10:00:05'}, 'user': userJson(1, 'somchai.j', credit: 350)});
      final s = storeFor(b);
      await s.login('somchai.j', 'password123');
      final (t, e1) = await s.createTopup(200);
      expect(e1, isNull);
      expect(await s.confirmTopup(t!), isNull);
      expect(t.status, TopupStatus.paid);
      expect(jsonDecode(b.lastCall('POST', '/api/topups')!.body), {'amount': 200});
    });

    test('feedback: ส่ง topic เป็นชื่อใน DB', () async {
      final b = studentBackend()..routes['POST /api/feedback'] = (_) => {'feedback_id': 1};
      final s = storeFor(b);
      await s.login('somchai.j', 'password123');
      expect(await s.submitFeedback(topic: FeedbackTopic.appBug, message: 'Map page is slow'), isNull);
      expect(jsonDecode(b.lastCall('POST', '/api/feedback')!.body), {'topic': 'app_bug', 'message': 'Map page is slow'});
    });

    test('studentBackend(withActiveRide: true) → has an active ride on EB-012', () async {
      final s = storeFor(studentBackend(withActiveRide: true));
      await s.login('somchai.j', 'password123');
      expect(s.activeRide?.rideId, 7);
      expect(s.vehicleByCode('EB-012')!.currentStationId, isNull);
      expect(s.vehiclesAt(1).map((v) => v.code), ['ES-016', 'EB-015', 'ES-031']);
    });

    test('logout ล้างข้อมูลและ token', () async {
      final s = storeFor(studentBackend());
      await s.login('somchai.j', 'password123');
      s.logout();
      expect(s.me, isNull);
      expect(s.stations, isEmpty);
      expect(s.api.token, isNull);
    });
  });

  group('แอดมิน', () {
    test('login แอดมิน → โหลดข้อมูลทั้งระบบ', () async {
      final s = storeFor(adminBackend());
      expect(await s.login('admin', 'password123'), isNull);
      expect(s.me!.isAdmin, isTrue);
      expect(s.allStations.length, 4);
      expect(s.stations.length, 3); // users can't see the closed station (Old Gate)
      expect(s.students.map((u) => u.username), ['somchai.j', 'malee.r']);
      expect(s.pendingTopups.single.topupId, 5);
      expect(s.urgentOpen.single.category, ReportCategory.accident);
      expect(s.unreadFeedback, 1);
      expect(s.revenueThisMonth, 100);
      expect(s.openRides.length, 1);
      expect(s.txnsOf(s.userById(1)).length, 1);
    });

    test('confirmTopup ของแอดมินใช้ /admin/topups/:id/confirm', () async {
      final b = adminBackend();
      b.routes['POST /api/admin/topups/5/confirm'] = (_) => {
            'topup': {
              'topup_id': 5,
              'user_id': 3,
              'amount': 200,
              'status': 'paid',
              'created_at': '2026-11-11 09:48:00',
              'paid_at': '2026-11-11 10:00:00',
            },
            'user': userJson(3, 'malee.r', credit: 240),
          };
      final s = storeFor(b);
      await s.login('admin', 'password123');
      final t = s.pendingTopups.single;
      expect(await s.confirmTopup(t), isNull);
      expect(t.status, TopupStatus.paid);
      expect(b.lastCall('POST', '/api/admin/topups/5/confirm'), isNotNull);
    });

    test('ส่งซ่อมรถที่มีคนยืม → ข้อความ error จาก backend', () async {
      final b = adminBackend()..routes['PUT /api/admin/vehicles/1/maintenance'] = (_) => FakeErr(409, 'Someone is riding this vehicle');
      final s = storeFor(b);
      await s.login('admin', 'password123');
      expect(await s.setMaintenance(s.vehicleById(1), true), 'Someone is riding this vehicle');
      expect(jsonDecode(b.lastCall('PUT', '/api/admin/vehicles/1/maintenance')!.body), {'repair': true});
    });
  });
}
