// Unit test ของ AdminStore (ไม่ต้องเปิดแอป) – รัน: flutter test
import 'package:ecoride_admin/data/admin_models.dart';
import 'package:ecoride_admin/data/admin_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = AdminStore.instance;

  test('dashboard counts match sample data', () {
    final s = store.summary;
    expect(s.totalStations, 4);
    expect(s.borrowedVehicles, 2);
    expect(s.maintenanceVehicles, 1);
  });

  test('station capacity must be at least 1', () {
    final err = store.addStation(AdminStation(
        stationId: 0, stationName: 'X', buildingName: 'Y', capacity: 0));
    expect(err, isNotNull);
  });

  test('available vehicle must have a station', () {
    final err = store.addVehicle(AdminVehicle(
        vehicleId: 0, vehicleCode: 'EB-099', qrCode: 'QR-EB-099',
        vehicleType: VehicleType.eBike, stationId: null));
    expect(err, contains('must be parked'));
  });

  test('duplicate vehicle code is rejected', () {
    final err = store.addVehicle(AdminVehicle(
        vehicleId: 0, vehicleCode: 'EB-001', qrCode: 'QR-NEW',
        vehicleType: VehicleType.eBike, stationId: 2));
    expect(err, contains('already exists'));
  });

  test('deactivate station is a soft delete', () {
    final lib = store.stations.first;
    store.deactivateStation(lib.stationId);
    expect(store.stations.length, 4);
    expect(store.stationById(lib.stationId)!.isActive, false);
    store.reactivateStation(lib.stationId);
  });
}
