// Fake backend shared by every test (unit tests + widget tests)
// Uses MockClient as the "backend" -> replies with JSON shaped exactly like the real API (backend/src/routes/index.js)
// so tests run without starting Node.js / MySQL. Run with: flutter test
//
// Usage:
//   import 'fake_backend.dart';                  // from a file in test/
//   import '../fake_backend.dart';               // from a file in test/<subfolder>/
//
//   final b = studentBackend();                   // or adminBackend(), studentBackend(withActiveRide: true)
//   b.routes['PUT /api/me'] = (req) => {...};     // add/override a route for a single test
//   b.routes['POST /api/rides'] = (_) => FakeErr(409, 'Not enough credit. Please top up first.'); // error reply
//   b.lastCall('POST', '/api/rides')              // inspect the request the app sent
//
// The sample data matches database/ecoride_db.sql (3 stations, vehicles EB-012..., somchai.j / admin / malee.r)
import 'dart:convert';

import 'package:ecoride_app/data/api_client.dart';
import 'package:ecoride_app/data/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// return this from a route to make the backend reply with an error: { "error": message }
class FakeErr {
  FakeErr(this.status, this.message);
  final int status;
  final String message;
}

class FakeBackend {
  /// key = 'METHOD /api/path' e.g. 'GET /api/rides', 'POST /api/rides/7/return'
  final Map<String, Object? Function(http.Request req)> routes = {};

  /// every request the app has sent (oldest first)
  final List<http.Request> calls = [];

  late final http.Client client = MockClient((req) async {
    calls.add(req);
    final handler = routes['${req.method} ${req.url.path}'];
    final Object? out = handler == null ? FakeErr(404, 'no route ${req.method} ${req.url.path}') : handler(req);
    final headers = {'content-type': 'application/json; charset=utf-8'};
    if (out is FakeErr) {
      return http.Response.bytes(utf8.encode(jsonEncode({'error': out.message})), out.status, headers: headers);
    }
    return http.Response.bytes(utf8.encode(jsonEncode(out)), 200, headers: headers);
  });

  /// most recent request matching method + path (null = the app never called it)
  http.Request? lastCall(String method, String path) {
    for (final c in calls.reversed) {
      if (c.method == method && c.url.path == path) return c;
    }
    return null;
  }

  /// body of the most recent request as a Map (handy for expect(...))
  Map<String, dynamic>? lastBody(String method, String path) {
    final c = lastCall(method, path);
    if (c == null || c.body.isEmpty) return null;
    return jsonDecode(c.body) as Map<String, dynamic>;
  }
}

// ============================================================ JSON builders (same shape as the real API)
const _names = {1: 'Somchai Jaidee', 2: 'EcoRide Admin', 3: 'Malee Ratanachai', 4: 'Krittin Wong'};
const _studentIds = {1: '6731501118', 3: '6731502229', 4: '6731501086'};

Map<String, Object?> userJson(int id, String username,
        {String role = 'student', num credit = 150, String? fullName, bool active = true}) =>
    {
      'user_id': id,
      'student_id': role == 'admin' ? 'ADMIN0001' : (_studentIds[id] ?? '67315011$id'),
      'username': username,
      'full_name': fullName ?? _names[id] ?? 'Test User $id',
      'credit_balance': credit,
      'role': role,
      'is_active': active ? 1 : 0,
      'avatar_id': null,
      'avatar_url': null,
    };

Map<String, Object?> stationJson(int id, String name, {int docks = 10, bool active = true, String icon = 'building'}) =>
    {
      'station_id': id,
      'name': name,
      'total_docks': docks,
      'icon_key': icon,
      'photo_url': null,
      'latitude': null,
      'longitude': null,
      'is_active': active ? 1 : 0,
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

/// one ride (default = ride 7 of somchai.j on EB-012, still active)
Map<String, Object?> rideJson({String status = 'active', int id = 7, int vehicleId = 1, int userId = 1}) => {
      'ride_id': id,
      'user_id': userId,
      'vehicle_id': vehicleId,
      'plan_id': 1,
      'start_station_id': 1,
      'return_station_id': status == 'returned' ? 1 : null,
      'start_time': '2026-11-11 09:00:00',
      'due_time': '2026-11-12 09:00:00',
      'end_time': status == 'returned' ? '2026-11-11 10:30:00' : null,
      'battery_start': 79,
      'battery_end': status == 'returned' ? 60 : null,
      'price_paid': 100,
      'status': status,
    };

Map<String, Object?> txnJson(int id, {int userId = 1, String type = 'ride_payment', num amount = -100,
        num balanceAfter = 150, int? rideId, int? topupId, String note = 'Ride payment', String? createdAt}) =>
    {
      'txn_id': id,
      'user_id': userId,
      'txn_type': type,
      'amount': amount,
      'balance_after': balanceAfter,
      'ride_id': rideId,
      'topup_id': topupId,
      'note': note,
      'created_at': createdAt ?? '2026-11-10 10:00:00',
    };

Map<String, Object?> topupJson(int id, {int userId = 1, num amount = 200, String status = 'pending'}) => {
      'topup_id': id,
      'user_id': userId,
      'amount': amount,
      'payment_method': 'qr',
      'reference_code': 'ECO$userId-$id',
      'status': status,
      'created_at': '2026-11-11 10:00:00',
      'paid_at': status == 'paid' ? '2026-11-11 10:00:05' : null,
    };

/// stations the student sees (GET /api/stations returns active ones only) – same as ecoride_db.sql
List<Map<String, Object?>> sampleStations() => [
      stationJson(1, 'Building 1', docks: 10),
      stationJson(2, 'Building 2', docks: 12),
      stationJson(3, 'Building 3', docks: 10),
    ];

/// vehicles – same as ecoride_db.sql (withActiveRide = EB-012 is being ridden by somchai.j)
List<Map<String, Object?>> sampleVehicles({bool withActiveRide = false}) => [
      withActiveRide ? vehicleJson(1, 'EB-012', 1, null, 79, status: 'in_use') : vehicleJson(1, 'EB-012', 1, 1, 79),
      vehicleJson(2, 'EB-015', 1, 1, 72),
      vehicleJson(3, 'ES-031', 2, 1, 12), // low battery -> charging, cannot be borrowed
      vehicleJson(4, 'ES-016', 2, 1, 91),
      vehicleJson(5, 'EB-021', 1, 2, 95),
      vehicleJson(6, 'ES-027', 2, null, 54, status: 'in_use'), // being ridden by someone else
      vehicleJson(7, 'ES-022', 2, 2, 80),
      vehicleJson(8, 'EB-004', 1, null, 77, status: 'in_use'),
    ];

// ============================================================ ready-made backends
/// student backend: log in as somchai.j / password123 (credit 150)
/// history contains 1 returned ride (ride 6) · withActiveRide: true = currently riding ride 7 on EB-012
FakeBackend studentBackend({bool withActiveRide = false}) {
  final b = FakeBackend();
  final me = userJson(1, 'somchai.j');
  final rides = [
    if (withActiveRide) rideJson(id: 7),
    {
      ...rideJson(id: 6, status: 'returned', vehicleId: 5),
      'start_time': '2026-11-10 08:00:00',
      'due_time': '2026-11-11 08:00:00',
      'end_time': '2026-11-10 09:15:00',
      'return_station_id': 2,
    },
  ];
  b.routes.addAll({
    // ---------- auth
    'POST /api/auth/login': (r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (body['password'] != 'password123') return FakeErr(401, 'Wrong username or password');
      return {'token': 'tok', 'user': me};
    },
    'POST /api/auth/register': (r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final user = userJson(9, body['username'] as String, fullName: body['full_name'] as String?, credit: 0);
      user['student_id'] = body['student_id'];
      return {'user': user};
    },
    'POST /api/auth/find-username': (_) => {'username': 'somchai.j'},
    'POST /api/auth/reset-password': (_) => {'ok': true},
    // ---------- account / profile
    'GET /api/me': (_) => me,
    'PUT /api/me': (r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return {...me, ...body};
    },
    'PUT /api/me/password': (_) => {'ok': true},
    // ---------- catalog
    'GET /api/vehicle-types': (_) => [
          {'type_id': 1, 'code_prefix': 'EB', 'name': 'Electric bicycle'},
          {'type_id': 2, 'code_prefix': 'ES', 'name': 'Electric scooter'},
        ],
    'GET /api/rental-plans': (_) => [
          {'plan_id': 1, 'name': '1 day (24 hrs)', 'duration_hours': 24, 'price': 100, 'is_active': 1},
        ],
    'GET /api/stations': (_) => sampleStations(),
    'GET /api/vehicles': (_) => sampleVehicles(withActiveRide: withActiveRide),
    // ---------- rides / credit
    'GET /api/rides': (_) => rides,
    'GET /api/credit/transactions': (_) => [
          txnJson(1, amount: -100, balanceAfter: 150, rideId: 6),
        ],
  });
  return b;
}

/// admin backend: log in as admin / password123 – loads data for the whole system
FakeBackend adminBackend() {
  final b = studentBackend();
  final admin = userJson(2, 'admin', role: 'admin', credit: 0);
  b.routes.addAll({
    'POST /api/auth/login': (r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (body['password'] != 'password123') return FakeErr(401, 'Wrong username or password');
      return {'token': 'adm', 'user': admin};
    },
    'GET /api/me': (_) => admin,
    // admin sees closed stations too (station 4 is closed -> not visible to students)
    'GET /api/admin/stations': (_) => [
          ...sampleStations(),
          stationJson(4, 'Old Gate', docks: 8, active: false, icon: 'school'),
        ],
    'GET /api/admin/rides': (_) => [rideJson()],
    'GET /api/admin/users': (_) => [userJson(1, 'somchai.j'), userJson(3, 'malee.r', credit: 40)],
    'GET /api/admin/topups': (_) => [
          {...topupJson(5, userId: 3), 'reference_code': 'ECO3-X', 'created_at': '2026-11-11 09:48:00'},
        ],
    'GET /api/admin/transactions': (_) => [
          txnJson(1, amount: -100, balanceAfter: 50, rideId: 7, createdAt: DateTime.now().toIso8601String()),
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
          {
            'feedback_id': 1,
            'user_id': 3,
            'topic': 'payment',
            'message': 'Credit was slow',
            'status': 'open',
            'created_at': '2026-11-11 08:00:00',
          }
        ],
  });
  return b;
}

// ============================================================ helpers for building an AppStore
/// AppStore that talks to the fake backend (logs out automatically when the test ends -> stops the timer)
AppStore storeFor(FakeBackend b) {
  final s = AppStore(ApiClient(client: b.client, baseUrl: 'http://test'));
  addTearDown(s.logout);
  return s;
}

/// for widget tests: replace AppStore.instance (which every screen uses) with a store wired to the fake backend
/// then log in right away – returns the store so you can expect(...) on it
///
///   testWidgets('...', (tester) async {
///     await signIn(tester, studentBackend());           // or signIn(tester, adminBackend(), username: 'admin')
///     await pumpApp(tester, const HomeShell());
///     expect(find.text('Building 1'), findsWidgets);
///   });
Future<AppStore> signIn(WidgetTester tester, FakeBackend b,
    {String username = 'somchai.j', String password = 'password123'}) async {
  final s = useFakeStore(b);
  // log in inside runAsync so the app's periodic Timer doesn't count as "pending" at the end of the test
  final err = await tester.runAsync(() => s.login(username, password));
  expect(err, isNull, reason: 'fake login failed');
  return s;
}

/// replace AppStore.instance without logging in (e.g. for testing the LoginScreen itself)
/// NOTE: if the test logs in through the UI, call AppStore.instance.logout() at the end of the test
AppStore useFakeStore(FakeBackend b) {
  final previous = AppStore.instance;
  final s = storeFor(b);
  AppStore.instance = s;
  addTearDown(() => AppStore.instance = previous);
  return s;
}

/// pump a screen/widget inside a MaterialApp at phone size (400x860) to avoid overflow errors on a wide screen
Future<void> pumpApp(WidgetTester tester, Widget child, {Size size = const Size(400, 860)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}
