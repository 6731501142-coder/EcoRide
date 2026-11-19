// Sprint 4 – Widget tests #2: Borrow/return and the map
//   screens/home_shell.dart   : Home tab (station list / "map"), current-ride banner, History tab
//   screens/ride_screens.dart : Select bike (choose a vehicle) · Vehicle detail · Payment confirm ·
//                               Ride summary (current ride) · Choose return station (return a vehicle)
//   + opening "Need help?" from the current ride (the HelpScreen form itself is tested by #1)
//   + one end-to-end flow: Home → station → vehicle → pay → ride → return → History
//
// Uses the shared fake backend (test/fake_backend.dart, by #6): signIn + pumpApp + studentBackend().
// fake_backend.dart is not edited – routes that need different data are overridden per test.
// Run: flutter test test/ride_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ecoride_app/screens/help_screen.dart';
import 'package:ecoride_app/screens/home_shell.dart';
import 'package:ecoride_app/screens/ride_screens.dart';
import 'package:ecoride_app/widgets/basic.dart';
import 'package:ecoride_app/widgets/form.dart';

import 'fake_backend.dart';

// ====================================================================== local helpers
/// Bigger than pumpApp's default 400×860: the test font draws every letter as a full square,
/// so text is much wider than on a real phone. This avoids false "RenderFlex overflowed".
const _size = Size(1000, 2000);

String _dbTime(DateTime d) => d.toIso8601String();

/// Active ride 7 on EB-012 with times relative to NOW (the shared rideJson() uses fixed
/// 2026-11-11 dates, so after 12 Nov it is always overdue). Default: started 1 h ago, due in 23 h.
Map<String, Object?> _freshRide({DateTime? start}) {
  final s = start ?? DateTime.now().subtract(const Duration(hours: 1));
  return {
    ...rideJson(id: 7),
    'start_time': _dbTime(s),
    'due_time': _dbTime(s.add(const Duration(hours: 24))),
  };
}

/// The rides the shared backend returns by default (1 returned ride: #6, EB-021).
List<Map<String, Object?>> _pastRides() {
  final original = studentBackend().routes['GET /api/rides']!;
  return (original(http.Request('GET', Uri.parse('http://test/api/rides'))) as List)
      .cast<Map<String, Object?>>();
}

/// Student who is riding EB-012 right now (not overdue unless [start] says so).
FakeBackend _ridingBackend({DateTime? start}) {
  final b = studentBackend(withActiveRide: true);
  b.routes['GET /api/rides'] = (_) => [_freshRide(start: start), ..._pastRides()];
  return b;
}

/// Student backend with a different credit balance.
FakeBackend _backendWithCredit(num credit) {
  final b = studentBackend();
  final me = userJson(1, 'somchai.j', credit: credit);
  b.routes['POST /api/auth/login'] = (_) => {'token': 'tok', 'user': me};
  b.routes['GET /api/me'] = (_) => me;
  return b;
}

int _count(FakeBackend b, String method, String path) =>
    b.calls.where((c) => c.method == method && c.url.path == path).length;

/// Open a placeholder "ROOT" page, then push [screen] on top (to check back / popUntil).
Future<void> _pushOnRoot(WidgetTester tester, Widget screen) async {
  await pumpApp(tester, const Scaffold(body: Center(child: Text('ROOT'))), size: _size);
  tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(builder: (_) => screen));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Value of the KPI box with [label] (e.g. _kpi(tester, 'Ready now') == '5').
String _kpi(WidgetTester tester, String label) =>
    tester.widget<Kpi>(find.ancestor(of: find.text(label), matching: find.byType(Kpi)).first).value;

/// Value on the right of an InfoRow (e.g. _info(tester, 'Price') == '฿100').
String _info(WidgetTester tester, String label) => tester
    .widget<InfoRow>(find.ancestor(of: find.text(label), matching: find.byType(InfoRow)).first)
    .value;

/// Btn with onTap == null is disabled.
bool _enabled(WidgetTester tester, String label) =>
    tester.widget<Btn>(find.widgetWithText(Btn, label)).onTap != null;

double _top(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(Key(key))).dy;

Finder _textMatching(RegExp re) =>
    find.byWidgetPredicate((w) => w is Text && w.data != null && re.hasMatch(w.data!));

// Sample data (fake_backend.dart = ecoride_db.sql):
//   Building 1 (10 docks): EB-012 79% · EB-015 72% · ES-031 12% (charging) · ES-016 91%
//   Building 2 (12 docks): EB-021 95% · ES-022 80%
//   Building 3 (10 docks): empty
void main() {
  // ==================================================================== Home tab
  group('Home tab – station list', () {
    testWidgets('greeting, KPIs and all 3 station cards', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const HomeShell(), size: _size);

      expect(find.text('Hello,'), findsOneWidget);
      expect(find.text('Somchai'), findsOneWidget);
      expect(_kpi(tester, 'Ready now'), '5'); // B1: EB-012, EB-015, ES-016 · B2: EB-021, ES-022
      expect(find.text('Select station'), findsOneWidget);

      expect(find.text('Building 1'), findsOneWidget);
      expect(find.text('2 bikes · 1 scooter · 6 free docks'), findsOneWidget);
      expect(find.widgetWithText(Pill, '3 ready'), findsOneWidget);

      expect(find.text('Building 2'), findsOneWidget);
      expect(find.widgetWithText(Pill, '2 ready'), findsOneWidget);

      expect(find.text('Building 3'), findsOneWidget);
      expect(find.text('0 bikes · 0 scooters · 10 free docks'), findsOneWidget);
      expect(find.widgetWithText(Pill, '0 ready'), findsOneWidget);
    });

    testWidgets('a full station shows "Full"', (tester) async {
      final b = studentBackend()..routes['GET /api/stations'] = (_) => [stationJson(1, 'Building 1', docks: 4)];
      await signIn(tester, b);
      await pumpApp(tester, const HomeShell(), size: _size);

      expect(find.text('2 bikes · 1 scooter · 0 free docks'), findsOneWidget);
      expect(find.widgetWithText(Pill, 'Full'), findsOneWidget);
    });

    testWidgets('closed stations are not shown to students', (tester) async {
      final b = studentBackend()
        ..routes['GET /api/stations'] = (_) => [
              stationJson(1, 'Building 1'),
              stationJson(4, 'Old Gate', active: false),
            ];
      await signIn(tester, b);
      await pumpApp(tester, const HomeShell(), size: _size);

      expect(find.text('Building 1'), findsOneWidget);
      expect(find.text('Old Gate'), findsNothing);
    });

    testWidgets('search (home_search) filters stations, "no match" text', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const HomeShell(), size: _size);
      final search = find.byKey(const Key('home_search'));

      await tester.enterText(search, 'building 2');
      await tester.pump();
      expect(find.text('Building 2'), findsOneWidget);
      expect(find.text('Building 1'), findsNothing);
      expect(find.text('Building 3'), findsNothing);

      await tester.enterText(search, 'xyz');
      await tester.pump();
      expect(find.text('No station matches "xyz"'), findsOneWidget);

      await tester.enterText(search, '');
      await tester.pump();
      expect(find.text('Building 1'), findsOneWidget);
      expect(find.text('Building 3'), findsOneWidget);
    });

    testWidgets('tapping a station opens Select bike', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const HomeShell(), size: _size);

      await _tap(tester, find.text('Building 1'));

      expect(find.byType(SelectBikeScreen), findsOneWidget);
      expect(find.text('Pick a vehicle to borrow'), findsOneWidget);
    });

    testWidgets('credit lower than the price -> top-up warning', (tester) async {
      await signIn(tester, _backendWithCredit(50));
      await pumpApp(tester, const HomeShell(), size: _size);

      expect(find.text('You need ฿100 to borrow. Tap to top up.'), findsOneWidget);
    });

    testWidgets('enough credit (฿150) -> no warning', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const HomeShell(), size: _size);

      expect(find.textContaining('You need'), findsNothing);
    });
  });

  // ==================================================================== Current-ride banner
  group('Home tab – current ride banner', () {
    testWidgets('no ride -> no banner', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const HomeShell(), size: _size);

      expect(find.text('YOU ARE RIDING'), findsNothing);
      expect(find.text('View ride & return'), findsNothing);
    });

    testWidgets('riding -> banner; tap opens the ride summary', (tester) async {
      await signIn(tester, _ridingBackend());
      await pumpApp(tester, const HomeShell(), size: _size);

      expect(find.text('YOU ARE RIDING'), findsOneWidget);
      expect(find.text('EB-012'), findsOneWidget);
      expect(find.textContaining('From Building 1 · return by'), findsOneWidget);
      expect(_kpi(tester, 'Ready now'), '4'); // EB-012 is out

      await _tap(tester, find.text('View ride & return'));
      expect(find.byType(RideSummaryScreen), findsOneWidget);
      expect(find.text('Riding · EB-012'), findsOneWidget);
    });

    testWidgets('overdue ride (shared rideJson, due 12 Nov) -> OVERDUE banner', (tester) async {
      await signIn(tester, studentBackend(withActiveRide: true));
      await pumpApp(tester, const HomeShell(), size: _size);

      expect(find.text('OVERDUE · RETURN NOW'), findsOneWidget);
      expect(find.text('YOU ARE RIDING'), findsNothing);
    });
  });

  // ==================================================================== History tab
  group('History tab', () {
    testWidgets('no rides -> "No rides yet"; nav back to Home', (tester) async {
      final b = studentBackend()..routes['GET /api/rides'] = (_) => [];
      await signIn(tester, b);
      await pumpApp(tester, const HomeShell(), size: _size);

      await _tap(tester, find.byKey(const Key('nav_1')));
      expect(find.text('No rides yet'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('nav_0')));
      expect(find.text('Select station'), findsOneWidget);
    });

    testWidgets('shows the returned ride (EB-021) and its detail popup', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const HomeShell(), size: _size);
      await _tap(tester, find.byKey(const Key('nav_1')));

      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('EB-021 · 10/11/2026'), findsOneWidget);
      expect(find.text('08:00 – 09:15 · 1 h 15 min'), findsOneWidget);
      expect(find.widgetWithText(Pill, 'Returned'), findsOneWidget);

      await _tap(tester, find.text('EB-021 · 10/11/2026'));
      expect(_info(tester, 'Borrowed'), '10/11/2026 · 08:00');
      expect(_info(tester, 'Returned'), '10/11/2026 · 09:15');
      expect(_info(tester, 'Total time'), '1 h 15 min');
      expect(_info(tester, 'Battery'), '79% → 60%');
      expect(_info(tester, 'Paid'), '฿100');

      await _tap(tester, find.text('Close'));
      expect(find.text('Borrowed'), findsNothing);
    });

    testWidgets('riding -> "Riding" badge above the returned ride', (tester) async {
      await signIn(tester, _ridingBackend());
      await pumpApp(tester, const HomeShell(), size: _size);
      await _tap(tester, find.byKey(const Key('nav_1')));

      final riding = find.widgetWithText(Pill, 'Riding');
      final returned = find.widgetWithText(Pill, 'Returned');
      expect(riding, findsOneWidget);
      expect(returned, findsOneWidget);
      expect(tester.getTopLeft(riding).dy, lessThan(tester.getTopLeft(returned).dy)); // newest first

      await _tap(tester, find.textContaining('Started '));
      expect(_info(tester, 'Returned'), '—');
      expect(_info(tester, 'Battery'), endsWith('(now)'));
    });

    testWidgets('overdue ride -> "Overdue" badge', (tester) async {
      await signIn(tester, studentBackend(withActiveRide: true));
      await pumpApp(tester, const HomeShell(), size: _size);
      await _tap(tester, find.byKey(const Key('nav_1')));

      expect(find.widgetWithText(Pill, 'Overdue'), findsOneWidget);
      expect(find.widgetWithText(Pill, 'Riding'), findsNothing);
    });
  });

  // ==================================================================== Select bike
  group('Select bike (choose a vehicle)', () {
    testWidgets('station 1 shows 4 vehicles, ready ones first by battery', (tester) async {
      final s = await signIn(tester, studentBackend());
      await _pushOnRoot(tester, SelectBikeScreen(station: s.stationById(1)));

      expect(_kpi(tester, 'Ready to ride'), '3');
      expect(_kpi(tester, 'Free docks'), '6/10');
      for (final code in ['ES-016', 'EB-012', 'EB-015', 'ES-031']) {
        expect(find.byKey(Key('bike_$code')), findsOneWidget);
      }
      expect(find.byKey(const Key('bike_EB-021')), findsNothing); // that one is at Building 2
      expect(_top(tester, 'bike_ES-016'), lessThan(_top(tester, 'bike_EB-012'))); // 91%
      expect(_top(tester, 'bike_EB-012'), lessThan(_top(tester, 'bike_EB-015'))); // 79%
      expect(_top(tester, 'bike_EB-015'), lessThan(_top(tester, 'bike_ES-031'))); // 72% then 12%
    });

    testWidgets('ES-031 (12%) shows red battery and "Charging · ready in ~N min"', (tester) async {
      final s = await signIn(tester, studentBackend());
      await _pushOnRoot(tester, SelectBikeScreen(station: s.stationById(1)));

      final low = find.byKey(const Key('bike_ES-031'));
      final pill = find.descendant(of: low, matching: find.widgetWithText(Pill, '12%'));
      expect(pill, findsOneWidget);
      expect(tester.widget<Pill>(pill).kind, PillKind.red);
      expect(find.descendant(of: low, matching: find.textContaining('Charging · ready in ~')), findsOneWidget);

      final ok = find.byKey(const Key('bike_EB-012'));
      expect(find.descendant(of: ok, matching: find.textContaining('ready in')), findsNothing);
    });

    testWidgets('filter chips: E-bikes / Scooters / All', (tester) async {
      final s = await signIn(tester, studentBackend());
      await _pushOnRoot(tester, SelectBikeScreen(station: s.stationById(1)));

      await _tap(tester, find.text('E-bikes'));
      expect(find.byKey(const Key('bike_EB-012')), findsOneWidget);
      expect(find.byKey(const Key('bike_ES-016')), findsNothing);

      await _tap(tester, find.text('Scooters'));
      expect(find.byKey(const Key('bike_ES-016')), findsOneWidget);
      expect(find.byKey(const Key('bike_EB-012')), findsNothing);

      await _tap(tester, find.text('All'));
      expect(find.byKey(const Key('bike_EB-012')), findsOneWidget);
      expect(find.byKey(const Key('bike_ES-016')), findsOneWidget);
    });

    testWidgets('vehicle under repair shows "Repair"', (tester) async {
      final b = studentBackend()
        ..routes['GET /api/vehicles'] = (_) => [
              vehicleJson(1, 'EB-012', 1, 1, 79),
              vehicleJson(9, 'EB-020', 1, 1, 50, status: 'maintenance'),
            ];
      final s = await signIn(tester, b);
      await _pushOnRoot(tester, SelectBikeScreen(station: s.stationById(1)));

      final row = find.byKey(const Key('bike_EB-020'));
      expect(find.descendant(of: row, matching: find.widgetWithText(Pill, 'Repair')), findsOneWidget);
      expect(_kpi(tester, 'Ready to ride'), '1');
    });

    testWidgets('Building 3 (empty) -> "No vehicles here right now"', (tester) async {
      final s = await signIn(tester, studentBackend());
      await _pushOnRoot(tester, SelectBikeScreen(station: s.stationById(3)));

      expect(find.text('No vehicles here right now'), findsOneWidget);
      expect(_kpi(tester, 'Free docks'), '10/10');
    });

    testWidgets('already riding -> "Return it first" warning', (tester) async {
      final s = await signIn(tester, studentBackend(withActiveRide: true));
      await _pushOnRoot(tester, SelectBikeScreen(station: s.stationById(1)));

      expect(find.text('You already have a vehicle out. Return it first.'), findsOneWidget);
      expect(find.byKey(const Key('bike_EB-012')), findsNothing); // not docked any more
    });

    testWidgets('tap a vehicle -> detail page; Back returns', (tester) async {
      final s = await signIn(tester, studentBackend());
      await _pushOnRoot(tester, SelectBikeScreen(station: s.stationById(1)));

      await _tap(tester, find.byKey(const Key('bike_EB-012')));
      expect(find.byType(VehicleDetailScreen), findsOneWidget);

      await _tap(tester, find.byTooltip('Back'));
      expect(find.byType(VehicleDetailScreen), findsNothing);
      expect(find.text('Pick a vehicle to borrow'), findsOneWidget);
    });
  });

  // ==================================================================== Vehicle detail
  group('Vehicle detail', () {
    testWidgets('EB-012: info rows, Borrow enabled -> Payment confirm', (tester) async {
      final s = await signIn(tester, studentBackend());
      await _pushOnRoot(tester, VehicleDetailScreen(vehicle: s.vehicleByCode('EB-012')!));

      expect(find.text('Electric bicycle'), findsOneWidget);
      expect(find.widgetWithText(Pill, 'Available'), findsOneWidget);
      expect(find.text('79%'), findsOneWidget);
      expect(_info(tester, 'Station'), 'Building 1');
      expect(_info(tester, 'Range when full'), '~67 km'); // 100 / 1.5 %/km
      expect(_info(tester, 'Rental plan'), '1 day (24 hrs)');
      expect(_info(tester, 'Price'), '฿100');
      expect(_enabled(tester, 'Borrow this vehicle'), isTrue);

      await _tap(tester, find.text('Borrow this vehicle'));
      expect(find.byType(PaymentConfirmScreen), findsOneWidget);
    });

    testWidgets('ES-016 scooter range ~33 km', (tester) async {
      final s = await signIn(tester, studentBackend());
      await _pushOnRoot(tester, VehicleDetailScreen(vehicle: s.vehicleByCode('ES-016')!));

      expect(find.text('Electric scooter'), findsOneWidget);
      expect(_info(tester, 'Range when full'), '~33 km'); // 100 / 3 %/km
    });

    testWidgets('ES-031 (12%): "Not ready yet" and Borrow disabled', (tester) async {
      final s = await signIn(tester, studentBackend());
      await _pushOnRoot(tester, VehicleDetailScreen(vehicle: s.vehicleByCode('ES-031')!));

      expect(find.widgetWithText(Pill, 'Not ready yet'), findsOneWidget);
      expect(find.textContaining('Can be borrowed in about'), findsOneWidget);
      expect(_enabled(tester, 'Borrow this vehicle'), isFalse);

      await tester.tap(find.text('Borrow this vehicle'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentConfirmScreen), findsNothing);
    });

    testWidgets('already riding another vehicle: Borrow disabled', (tester) async {
      final s = await signIn(tester, studentBackend(withActiveRide: true));
      await _pushOnRoot(tester, VehicleDetailScreen(vehicle: s.vehicleByCode('EB-015')!));

      expect(_enabled(tester, 'Borrow this vehicle'), isFalse);
    });
  });

  // ==================================================================== Payment confirm
  group('Payment confirm', () {
    testWidgets('credit ฿150: summary, ฿50 after payment, Confirm enabled', (tester) async {
      final s = await signIn(tester, studentBackend());
      await _pushOnRoot(tester, PaymentConfirmScreen(vehicle: s.vehicleByCode('EB-012')!));

      expect(_info(tester, 'Username'), 'somchai.j');
      expect(_info(tester, 'Bike ID'), 'EB-012');
      expect(_info(tester, 'Station'), 'Building 1');
      expect(_info(tester, 'Plan'), '1 day (24 hrs) / ฿100');
      expect(_kpi(tester, 'Current credits'), '฿150');
      expect(_kpi(tester, 'After payment'), '฿50');
      expect(_enabled(tester, 'Confirm'), isTrue);
    });

    testWidgets('credit ฿50: top-up message, Add credit, Confirm disabled', (tester) async {
      final b = _backendWithCredit(50);
      final s = await signIn(tester, b);
      await _pushOnRoot(tester, PaymentConfirmScreen(vehicle: s.vehicleByCode('EB-012')!));

      expect(_kpi(tester, 'After payment'), '—');
      expect(find.text('Not enough credit. Top up at least ฿50 to continue.'), findsOneWidget);
      expect(find.widgetWithText(Btn, 'Add credit'), findsOneWidget);
      expect(_enabled(tester, 'Confirm'), isFalse);

      await tester.tap(find.byKey(const Key('btn_confirm_pay')));
      await tester.pumpAndSettle();
      expect(_count(b, 'POST', '/api/rides'), 0);
    });

    testWidgets('btn_confirm_pay -> sends {vehicle_id, plan_id}, opens the ride summary', (tester) async {
      final b = studentBackend();
      var riding = false;
      b.routes['GET /api/rides'] = (_) => [if (riding) _freshRide(), ..._pastRides()];
      b.routes['GET /api/vehicles'] = (_) => sampleVehicles(withActiveRide: riding);
      b.routes['POST /api/rides'] = (_) {
        riding = true;
        return {'ride': _freshRide(), 'user': userJson(1, 'somchai.j', credit: 50)};
      };
      final s = await signIn(tester, b);
      await _pushOnRoot(tester, PaymentConfirmScreen(vehicle: s.vehicleByCode('EB-012')!));

      await _tap(tester, find.byKey(const Key('btn_confirm_pay')));

      expect(b.lastBody('POST', '/api/rides'), {'vehicle_id': 1, 'plan_id': 1});
      expect(find.textContaining('Enjoy your ride! Return by'), findsOneWidget);
      expect(find.byType(RideSummaryScreen), findsOneWidget);
      expect(find.byType(PaymentConfirmScreen), findsNothing); // stack reset to the first page
      expect(s.activeRide?.rideId, 7);

      await _tap(tester, find.byTooltip('Back'));
      expect(find.text('ROOT'), findsOneWidget);
    });

    testWidgets('backend error -> message shown, stays on the page', (tester) async {
      final b = studentBackend()
        ..routes['POST /api/rides'] = (_) => FakeErr(409, 'Not enough credit. Please top up first.');
      final s = await signIn(tester, b);
      await _pushOnRoot(tester, PaymentConfirmScreen(vehicle: s.vehicleByCode('EB-012')!));

      await _tap(tester, find.byKey(const Key('btn_confirm_pay')));

      expect(find.text('Not enough credit. Please top up first.'), findsOneWidget);
      expect(find.byType(PaymentConfirmScreen), findsOneWidget);
      expect(s.activeRide, isNull);
    });
  });

  // ==================================================================== Ride summary
  group('Ride summary (current ride)', () {
    testWidgets('no active ride -> "No active ride"', (tester) async {
      await signIn(tester, studentBackend());
      await _pushOnRoot(tester, const RideSummaryScreen());

      expect(find.text('No active ride'), findsOneWidget);
      expect(find.byKey(const Key('btn_return')), findsNothing);
    });

    testWidgets('riding EB-012: countdown, battery, start station', (tester) async {
      await signIn(tester, _ridingBackend());
      await _pushOnRoot(tester, const RideSummaryScreen());

      expect(find.text('Riding · EB-012'), findsOneWidget);
      expect(find.text('Time left to return'), findsOneWidget);
      expect(_textMatching(RegExp(r'^22:5\d:\d\d$')), findsOneWidget); // 24 h plan, started 1 h ago
      // 1 h = 0.6 h moving × 12 km/h = 7.2 km × 1.5 %/km = 10.8 % used -> 79 - 10.8 = 68
      expect(find.text('Battery 68%'), findsOneWidget);
      expect(find.text('~7.2 km · estimated'), findsOneWidget);
      expect(find.text('From: Building 1'), findsOneWidget);
      expect(find.textContaining('Return by '), findsOneWidget);
    });

    testWidgets('overdue -> "Overdue by" and a negative countdown', (tester) async {
      await signIn(tester, _ridingBackend(start: DateTime.now().subtract(const Duration(hours: 30))));
      await _pushOnRoot(tester, const RideSummaryScreen());

      expect(find.text('Overdue by'), findsOneWidget);
      expect(find.text('Time left to return'), findsNothing);
      expect(_textMatching(RegExp(r'^-0[56]:\d\d:\d\d$')), findsOneWidget); // ~6 h late
    });

    testWidgets('btn_return -> Choose return station', (tester) async {
      await signIn(tester, _ridingBackend());
      await _pushOnRoot(tester, const RideSummaryScreen());

      await _tap(tester, find.byKey(const Key('btn_return')));
      expect(find.byType(ReturnStationScreen), findsOneWidget);
    });

    testWidgets('btn_need_help -> opens "Need help?" (report a problem)', (tester) async {
      await signIn(tester, _ridingBackend());
      await _pushOnRoot(tester, const RideSummaryScreen());

      await _tap(tester, find.byKey(const Key('btn_need_help')));
      expect(find.byType(HelpScreen), findsOneWidget);
      expect(find.text('What happened to EB-012?'), findsOneWidget);
    });
  });

  // ==================================================================== Return a vehicle
  group('Choose return station (return a vehicle)', () {
    testWidgets('only the start station is allowed, the others are locked', (tester) async {
      final s = await signIn(tester, _ridingBackend());
      await _pushOnRoot(tester, ReturnStationScreen(ride: s.activeRide!));

      // Building 1: EB-012 is out -> 3 docked -> 7 of 10 free
      expect(find.text('Your start station · 7 / 10 docks free'), findsOneWidget);
      expect(find.text("Can't return here"), findsNWidgets(2)); // Building 2 and 3
      expect(find.widgetWithText(Pill, 'Locked'), findsNWidgets(2));
      expect(_enabled(tester, 'Confirm return'), isTrue);
    });

    testWidgets('start station full -> warning, Confirm return disabled', (tester) async {
      final b = _ridingBackend()..routes['GET /api/stations'] = (_) => [stationJson(1, 'Building 1', docks: 3)];
      final s = await signIn(tester, b);
      await _pushOnRoot(tester, ReturnStationScreen(ride: s.activeRide!));

      expect(find.text('Building 1 is full right now. Please wait for a free dock.'), findsOneWidget);
      expect(_enabled(tester, 'Confirm return'), isFalse);

      await tester.tap(find.byKey(const Key('btn_confirm_return')));
      await tester.pumpAndSettle();
      expect(_count(b, 'POST', '/api/rides/7/return'), 0);
    });

    testWidgets('btn_confirm_return -> sends {station_id: 1}, back to the first page', (tester) async {
      final b = _ridingBackend();
      var returned = false;
      b.routes['GET /api/rides'] = (_) => [
            if (!returned) _freshRide() else rideJson(status: 'returned'),
            ..._pastRides(),
          ];
      b.routes['GET /api/vehicles'] = (_) => sampleVehicles(withActiveRide: !returned);
      b.routes['POST /api/rides/7/return'] = (_) {
        returned = true;
        return rideJson(status: 'returned');
      };
      final s = await signIn(tester, b);
      await _pushOnRoot(tester, ReturnStationScreen(ride: s.activeRide!));

      await _tap(tester, find.byKey(const Key('btn_confirm_return')));

      expect(b.lastBody('POST', '/api/rides/7/return'), {'station_id': 1});
      expect(find.text('Returned at Building 1. Thank you!'), findsOneWidget);
      expect(find.text('ROOT'), findsOneWidget);
      expect(s.activeRide, isNull);
    });

    testWidgets('backend error -> message shown, stays on the page', (tester) async {
      final b = _ridingBackend()..routes['POST /api/rides/7/return'] = (_) => FakeErr(409, 'This station is full');
      final s = await signIn(tester, b);
      await _pushOnRoot(tester, ReturnStationScreen(ride: s.activeRide!));

      await _tap(tester, find.byKey(const Key('btn_confirm_return')));

      expect(find.text('This station is full'), findsOneWidget);
      expect(find.byType(ReturnStationScreen), findsOneWidget);
      expect(s.activeRide, isNotNull);
    });
  });

  // ==================================================================== Whole flow
  testWidgets('flow: Home → station → vehicle → pay → ride → return → History', (tester) async {
    final b = studentBackend();
    var state = 'idle'; // idle -> riding -> returned
    var credit = 150;
    b.routes['GET /api/me'] = (_) => userJson(1, 'somchai.j', credit: credit);
    b.routes['GET /api/vehicles'] = (_) => sampleVehicles(withActiveRide: state == 'riding');
    b.routes['GET /api/rides'] = (_) => [
          if (state == 'riding') _freshRide(),
          if (state == 'returned') {..._freshRide(), 'status': 'returned', 'end_time': _dbTime(DateTime.now())},
          ..._pastRides(),
        ];
    b.routes['POST /api/rides'] = (_) {
      state = 'riding';
      credit = 50;
      return {'ride': _freshRide(), 'user': userJson(1, 'somchai.j', credit: credit)};
    };
    b.routes['POST /api/rides/7/return'] = (_) {
      state = 'returned';
      return rideJson(status: 'returned');
    };
    final s = await signIn(tester, b);
    await pumpApp(tester, const HomeShell(), size: _size);

    await _tap(tester, find.text('Building 1'));
    await _tap(tester, find.byKey(const Key('bike_EB-012')));
    await _tap(tester, find.text('Borrow this vehicle'));
    await _tap(tester, find.byKey(const Key('btn_confirm_pay')));
    expect(find.text('Riding · EB-012'), findsOneWidget);
    // let the "Enjoy your ride!" SnackBar (4 s) go away – it sits over the bottom buttons
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip('Back'));
    expect(find.text('YOU ARE RIDING'), findsOneWidget);
    expect(s.me!.creditBalance, 50);

    await _tap(tester, find.text('View ride & return'));
    await _tap(tester, find.byKey(const Key('btn_return')));
    await _tap(tester, find.byKey(const Key('btn_confirm_return')));
    expect(find.text('Returned at Building 1. Thank you!'), findsOneWidget);
    expect(find.text('YOU ARE RIDING'), findsNothing);

    await _tap(tester, find.byKey(const Key('nav_1')));
    expect(find.widgetWithText(Pill, 'Returned'), findsNWidgets(2)); // today's ride + ride 6
  });
}
