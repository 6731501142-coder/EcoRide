// Sprint 4: Admin – stations & vehicles
// (admin/stations_screen, admin/vehicles_screen)
// Add/edit stations and vehicles, send a vehicle for repair
// รัน: flutter test test/admin_stations_vehicles_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:ecoride_app/admin/stations_screen.dart';
import 'package:ecoride_app/admin/vehicles_screen.dart';
// import 'package:ecoride_app/data/app_store.dart';
import 'package:ecoride_app/data/models.dart';

import 'fake_backend.dart';

/// Admin fake backend with mutable stations/vehicles so Save/Add/Repair refresh correctly.
FakeBackend stationsVehiclesBackend() {
  final b = adminBackend();
  final stations = <Map<String, Object?>>[
    ...sampleStations(),
    stationJson(4, 'Old Gate', docks: 8, active: false, icon: 'school'),
  ];
  var vehicles = List<Map<String, Object?>>.from(sampleVehicles());

  b.routes['GET /api/admin/stations'] = (_) => List<Map<String, Object?>>.from(stations);
  b.routes['GET /api/vehicles'] = (_) => List<Map<String, Object?>>.from(vehicles);

  b.routes['POST /api/admin/stations'] = (r) {
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final id = (stations.map((s) => s['station_id'] as int).fold<int>(0, (a, c) => a > c ? a : c)) + 1;
    stations.add(stationJson(
      id,
      body['name'] as String,
      docks: (body['total_docks'] as num).toInt(),
    ));
    return {'ok': true, 'station_id': id};
  };

  for (final id in [1, 2, 3, 4]) {
    b.routes['PUT /api/admin/stations/$id'] = (r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final i = stations.indexWhere((s) => s['station_id'] == id);
      if (i >= 0) {
        stations[i] = {
          ...stations[i],
          if (body['name'] != null) 'name': body['name'],
          if (body['total_docks'] != null) 'total_docks': body['total_docks'],
          if (body['is_active'] != null) 'is_active': (body['is_active'] == true || body['is_active'] == 1) ? 1 : 0,
          if (body['icon_key'] != null) 'icon_key': body['icon_key'],
        };
      }
      return {'ok': true};
    };
  }

  b.routes['POST /api/admin/vehicles'] = (r) {
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final typeId = (body['type_id'] as num).toInt();
    final number = (body['number'] as String).trim().padLeft(3, '0');
    final stationId = (body['station_id'] as num).toInt();
    final prefix = typeId == 1 ? 'EB' : 'ES';
    final id = (vehicles.map((v) => v['vehicle_id'] as int).fold<int>(0, (a, c) => a > c ? a : c)) + 1;
    vehicles = [
      ...vehicles,
      vehicleJson(id, '$prefix-$number', typeId, stationId, 100),
    ];
    return {'ok': true, 'vehicle_id': id};
  };

  for (final id in [1, 2, 3, 4, 5, 6, 7, 8, 9]) {
    b.routes['PUT /api/admin/vehicles/$id/maintenance'] = (r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final repair = body['repair'] == true;
      vehicles = [
        for (final v in vehicles)
          if (v['vehicle_id'] == id)
            {
              ...v,
              'status': repair ? 'maintenance' : 'available',
            }
          else
            v,
      ];
      return {'ok': true};
    };
  }

  return b;
}

void main() {
  const testSize = Size(800, 1000);

  // ---------------------------------------------------------- 1. Add station
  testWidgets('StationsTab: เพิ่มสถานีใหม่ได้', (tester) async {
    final b = stationsVehiclesBackend();
    await signIn(tester, b, username: 'admin');
    await pumpApp(tester, const Scaffold(body: StationsTab()), size: testSize);
    await tester.pumpAndSettle();

    expect(find.text('Stations'), findsOneWidget);
    expect(find.text('Building 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Add station'));
    await tester.pumpAndSettle();

    expect(find.text('Add station'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Library');
    await tester.enterText(fields.at(1), '14');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(b.lastCall('POST', '/api/admin/stations'), isNotNull);
    expect(b.lastBody('POST', '/api/admin/stations'), containsPair('name', 'Library'));
    expect(b.lastBody('POST', '/api/admin/stations'), containsPair('total_docks', 14));
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Station added'), findsOneWidget);
  });

  // ---------------------------------------------------------- 2. Edit station
  testWidgets('StationsTab: แก้ไขชื่อ/จำนวนช่อง และปิดสถานีได้', (tester) async {
    final b = stationsVehiclesBackend();
    await signIn(tester, b, username: 'admin');
    await pumpApp(tester, const Scaffold(body: StationsTab()), size: testSize);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerIcons.pencil).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit station'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Building 1 West');
    await tester.enterText(fields.at(1), '16');
    await tester.tap(find.byType(Switch));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(b.lastCall('PUT', '/api/admin/stations/1'), isNotNull);
    final body = b.lastBody('PUT', '/api/admin/stations/1')!;
    expect(body['name'], 'Building 1 West');
    expect(body['total_docks'], 16);
    expect(body['is_active'], false);
    expect(find.text('Building 1 West'), findsOneWidget);
    expect(find.text('Station saved'), findsOneWidget);
  });

  // ---------------------------------------------------------- 3. Add vehicle
  testWidgets('VehiclesTab: เพิ่มรถใหม่ได้', (tester) async {
    final b = stationsVehiclesBackend();
    await signIn(tester, b, username: 'admin');
    await pumpApp(tester, const Scaffold(body: VehiclesTab()), size: testSize);
    await tester.pumpAndSettle();

    expect(find.text('Vehicles'), findsOneWidget);
    expect(find.text('EB-012'), findsOneWidget);

    await tester.tap(find.byTooltip('Add vehicle'));
    await tester.pumpAndSettle();

    expect(find.text('Add vehicle'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '099');
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();

    expect(b.lastCall('POST', '/api/admin/vehicles'), isNotNull);
    expect(b.lastBody('POST', '/api/admin/vehicles'), {
      'type_id': 1,
      'number': '099',
      'station_id': 1,
    });
    expect(find.text('EB-099'), findsOneWidget);
    expect(find.textContaining('Vehicle added to'), findsOneWidget);
  });

  // ---------------------------------------------------------- 4. Send vehicle for repair
  testWidgets('VehiclesTab: ส่งรถไปซ่อมได้', (tester) async {
    final b = stationsVehiclesBackend();
    final s = await signIn(tester, b, username: 'admin');
    await pumpApp(tester, const Scaffold(body: VehiclesTab()), size: testSize);
    await tester.pumpAndSettle();

    expect(s.vehicleByCode('EB-012')!.status, VehicleStatus.available);

    await tester.tap(find.text('EB-012'));
    await tester.pumpAndSettle();

    expect(find.text('Send to repair'), findsOneWidget);
    await tester.tap(find.text('Send to repair'));
    await tester.pumpAndSettle();

    expect(b.lastCall('PUT', '/api/admin/vehicles/1/maintenance'), isNotNull);
    expect(b.lastBody('PUT', '/api/admin/vehicles/1/maintenance'), {'repair': true});
    expect(s.vehicleByCode('EB-012')!.status, VehicleStatus.maintenance);
    expect(find.text('Back in service'), findsOneWidget);
  });

  // ---------------------------------------------------------- 5. Back in service (edit vehicle repair status)
  testWidgets('VehiclesTab: นำรถที่ส่งซ่อมกลับมาให้บริการได้', (tester) async {
    final b = stationsVehiclesBackend();
    var vehicles = [
      for (final v in sampleVehicles())
        if (v['vehicle_id'] == 2) {...v, 'status': 'maintenance'} else v,
    ];
    b.routes['GET /api/vehicles'] = (_) => List<Map<String, Object?>>.from(vehicles);
    b.routes['PUT /api/admin/vehicles/2/maintenance'] = (r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final repair = body['repair'] == true;
      vehicles = [
        for (final v in vehicles)
          if (v['vehicle_id'] == 2)
            {...v, 'status': repair ? 'maintenance' : 'available'}
          else
            v,
      ];
      return {'ok': true};
    };

    final s = await signIn(tester, b, username: 'admin');
    await pumpApp(tester, const Scaffold(body: VehiclesTab()), size: testSize);
    await tester.pumpAndSettle();

    expect(s.vehicleByCode('EB-015')!.status, VehicleStatus.maintenance);

    await tester.tap(find.text('EB-015'));
    await tester.pumpAndSettle();

    expect(find.text('Back in service'), findsOneWidget);
    await tester.tap(find.text('Back in service'));
    await tester.pumpAndSettle();

    expect(b.lastCall('PUT', '/api/admin/vehicles/2/maintenance'), isNotNull);
    expect(b.lastBody('PUT', '/api/admin/vehicles/2/maintenance'), {'repair': false});
    expect(s.vehicleByCode('EB-015')!.status, VehicleStatus.available);
  });
}
