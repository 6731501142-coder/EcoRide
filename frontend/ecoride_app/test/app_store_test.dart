// ทดสอบ AppStore + ApiClient โดยไม่ต้องเปิด backend จริง: ใช้ MockClient เป็น "backend ปลอม"
// (ตอบ JSON หน้าตาเดียวกับ API จริง) – รันด้วย: flutter test
// กฎธุรกิจจริง (หักเครดิต คืนรถ ฯลฯ) ทดสอบฝั่ง backend แล้วด้วย jest (backend/tests)
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ecoride_app/data/api_client.dart';
import 'package:ecoride_app/data/app_store.dart';
import 'package:ecoride_app/data/models.dart';

/// backend ปลอม: routes['GET /api/rides'] = (req) => ข้อมูลที่จะตอบ (หรือ _Err เพื่อตอบ error)
class _Err {
  _Err(this.status, this.message);
  final int status;
  final String message;
}

class FakeBackend {
  final Map<String, Object? Function(http.Request req)> routes = {};
  final List<http.Request> calls = [];

  late final http.Client client = MockClient((req) async {
    calls.add(req);
    final handler = routes['${req.method} ${req.url.path}'];
    final Object? out = handler == null ? _Err(404, 'no route ${req.method} ${req.url.path}') : handler(req);
    final headers = {'content-type': 'application/json; charset=utf-8'};
    if (out is _Err) return http.Response.bytes(utf8.encode(jsonEncode({'error': out.message})), out.status, headers: headers);
    return http.Response.bytes(utf8.encode(jsonEncode(out)), 200, headers: headers);
  });

  http.Request? lastCall(String method, String path) {
    for (final c in calls.reversed) {
      if (c.method == method && c.url.path == path) return c;
    }
    return null;
  }
}

Map<String, Object?> userJson(int id, String username, {String role = 'student', num credit = 150}) => {
      'user_id': id,
      'student_id': role == 'admin' ? 'ADMIN0001' : '67315011$id',
      'username': username,
      'full_name': role == 'admin' ? 'EcoRide Admin' : 'Somchai Jaidee',
      'credit_balance': credit,
      'role': role,
      'is_active': 1,
      'avatar_id': null,
      'avatar_url': null,
    };

Map<String, Object?> vehicleJson(int id, String code, int type, int? station, int battery,
        {String status = 'available'}) =>
    {
      'vehicle_id': id,
      'vehicle_code': code,
      'type_id': type,
      'current_station_id': station,
      'battery_level': battery,
      'live_battery': battery,
      'status': status,
    };

Map<String, Object?> rideJson({String status = 'active', int id = 7}) => {
      'ride_id': id,
      'user_id': 1,
      'vehicle_id': 1,
      'plan_id': 1,
      'start_station_id': 1,
      'return_station_id': null,
      'start_time': '2026-11-11 09:00:00',
      'due_time': '2026-11-12 09:00:00',
      'end_time': null,
      'battery_start': 79,
      'battery_end': null,
      'price_paid': 100,
      'status': status,
    };

/// ข้อมูลฝั่งนักศึกษา (ตรงกับ ecoride_db.sql: Building 1 มีรถ 4 คัน)
FakeBackend studentBackend() {
  final b = FakeBackend();
  final me = userJson(1, 'somchai.j');
  b.routes.addAll({
    'POST /api/auth/login': (r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (body['password'] != 'password123') return _Err(401, 'Wrong username or password');
      return {'token': 'tok', 'user': me};
    },
    'GET /api/me': (_) => me,
    'GET /api/vehicle-types': (_) => [
          {'type_id': 1, 'code_prefix': 'EB', 'name': 'Electric bicycle'},
          {'type_id': 2, 'code_prefix': 'ES', 'name': 'Electric scooter'},
        ],
    'GET /api/rental-plans': (_) => [
          {'plan_id': 1, 'name': '1 day (24 hrs)', 'duration_hours': 24, 'price': 100, 'is_active': 1},
        ],
    'GET /api/stations': (_) => [
          {'station_id': 1, 'name': 'Building 1', 'total_docks': 10, 'icon_key': 'building', 'photo_url': null, 'is_active': 1},
        ],
    'GET /api/vehicles': (_) => [
          vehicleJson(1, 'EB-012', 1, 1, 79),
          vehicleJson(2, 'EB-015', 1, 1, 72),
          vehicleJson(3, 'ES-031', 2, 1, 12),
          vehicleJson(4, 'ES-016', 2, 1, 91),
        ],
    'GET /api/rides': (_) => [],
    'GET /api/credit/transactions': (_) => [],
  });
  return b;
}

AppStore storeFor(FakeBackend b) {
  final s = AppStore(ApiClient(client: b.client, baseUrl: 'http://test'));
  addTearDown(s.logout); // หยุดตัวจับเวลา
  return s;
}

void main() {
  group('ApiClient', () {
    test('แนบ token และอ่านข้อความ error จาก backend', () async {
      final b = FakeBackend();
      b.routes['GET /api/me'] = (r) => r.headers['Authorization'] == 'Bearer abc' ? {'ok': true} : _Err(401, 'Please log in');
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
      expect(s.stations.map((x) => x.name), ['Building 1']);
      expect(s.defaultPlan.price, 100);

      // รถที่พร้อมยืมขึ้นก่อน เรียงแบตมากไปน้อย
      expect(s.vehiclesAt(1).map((v) => v.code), ['ES-016', 'EB-012', 'EB-015', 'ES-031']);
      final a = s.availability(s.stationById(1));
      expect((a.readyBikes, a.readyScooters, a.docked, a.freeDocks, a.full), (2, 1, 4, 6, false));
      expect(s.vehicleByCode(' es-031 ')!.vehicleId, 3);
    });

    test('แบต: รถจอดชาร์จ + รถแบตต่ำรอกี่นาที', () async {
      final s = storeFor(studentBackend());
      await s.login('somchai.j', 'password123');
      final low = s.vehicleByCode('ES-031')!; // 12%
      expect(s.canBorrowVehicle(low), isFalse);
      expect(s.isCharging(low), isTrue);
      expect(s.minutesUntilReady(low), 15); // (20-12) / 32%ต่อชม. ≈ 15 นาที
      expect(s.estimatedKm(s.vehicleByCode('EB-012')!, const Duration(hours: 1)), closeTo(7.2, 0.01));
      expect(s.canBorrowVehicle(s.vehicleByCode('EB-012')!), isTrue);
    });

    test('borrow: backend ปฏิเสธ → ได้ข้อความ error เดิมของแอป', () async {
      final b = studentBackend()..routes['POST /api/rides'] = (_) => _Err(409, 'Not enough credit. Please top up first.');
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
        ..routes['POST /api/topups'] = (_) => topup
        ..routes['POST /api/topups/3/confirm'] =
            (_) => {'topup': {...topup, 'status': 'paid', 'paid_at': '2026-11-11 10:00:05'}, 'user': userJson(1, 'somchai.j', credit: 350)};
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
    FakeBackend adminBackend() {
      final b = studentBackend();
      final admin = userJson(2, 'admin', role: 'admin', credit: 0);
      b.routes.addAll({
        'POST /api/auth/login': (_) => {'token': 'adm', 'user': admin},
        'GET /api/me': (_) => admin,
        'GET /api/admin/stations': (_) => [
              {'station_id': 1, 'name': 'Building 1', 'total_docks': 10, 'icon_key': 'building', 'photo_url': null, 'is_active': 1},
              {'station_id': 2, 'name': 'Building 2', 'total_docks': 12, 'icon_key': 'school', 'photo_url': null, 'is_active': 0},
            ],
        'GET /api/admin/rides': (_) => [rideJson()],
        'GET /api/admin/users': (_) => [userJson(1, 'somchai.j'), userJson(3, 'malee.r', credit: 40)],
        'GET /api/admin/topups': (_) => [
              {
                'topup_id': 5,
                'user_id': 3,
                'amount': 200,
                'payment_method': 'qr',
                'reference_code': 'ECO3-X',
                'status': 'pending',
                'created_at': '2026-11-11 09:48:00',
                'paid_at': null,
              }
            ],
        'GET /api/admin/transactions': (_) => [
              {
                'txn_id': 1,
                'user_id': 1,
                'txn_type': 'ride_payment',
                'amount': -100,
                'balance_after': 50,
                'ride_id': 7,
                'topup_id': null,
                'note': 'Ride payment',
                'created_at': DateTime.now().toIso8601String(),
              }
            ],
        'GET /api/admin/reports': (_) => [
              {
                'report_id': 2,
                'user_id': 1,
                'vehicle_id': 1,
                'ride_id': 7,
                'category': 'accident',
                'is_urgent': true,
                'details': '[URGENT] Accident · at: gate 2',
                'status': 'open',
                'created_at': '2026-11-11 09:10:00',
                'resolved_at': null,
              }
            ],
        'GET /api/admin/feedback': (_) => [
              {'feedback_id': 1, 'user_id': 3, 'topic': 'payment', 'message': 'Credit was slow', 'status': 'open', 'created_at': '2026-11-11 08:00:00'}
            ],
      });
      return b;
    }

    test('login แอดมิน → โหลดข้อมูลทั้งระบบ', () async {
      final s = storeFor(adminBackend());
      expect(await s.login('admin', 'password123'), isNull);
      expect(s.me!.isAdmin, isTrue);
      expect(s.allStations.length, 2);
      expect(s.stations.length, 1); // สถานีที่ปิดอยู่ผู้ใช้ไม่เห็น
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
      final b = adminBackend()..routes['PUT /api/admin/vehicles/1/maintenance'] = (_) => _Err(409, 'Someone is riding this vehicle');
      final s = storeFor(b);
      await s.login('admin', 'password123');
      expect(await s.setMaintenance(s.vehicleById(1), true), 'Someone is riding this vehicle');
      expect(jsonDecode(b.lastCall('PUT', '/api/admin/vehicles/1/maintenance')!.body), {'repair': true});
    });
  });
}
