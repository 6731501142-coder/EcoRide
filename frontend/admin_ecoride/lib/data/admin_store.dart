// AdminStore – "Model" ฝั่ง Admin (MVC)
// เก็บข้อมูลสถานี/รถแบบ mock ไว้ในหน่วยความจำ + ฟังก์ชัน CRUD
// กฎทุกข้อเลียนแบบ constraint ใน ecoride_backend_schema_v2.sql
// Sprint 3: เปลี่ยนตัวฟังก์ชันข้างในให้เรียก API (Dio) แทน โดยหน้าจอไม่ต้องแก้
import 'package:flutter/foundation.dart';

import 'admin_models.dart';

class AdminStore extends ChangeNotifier {
  AdminStore._() {
    _seed();
  }
  static final AdminStore instance = AdminStore._(); // ใช้ร่วมกันทุกหน้า

  final List<AdminStation> _stations = [];
  final List<AdminVehicle> _vehicles = [];
  int _nextStationId = 1;
  int _nextVehicleId = 1;

  List<AdminStation> get stations => List.unmodifiable(_stations);
  List<AdminVehicle> get vehicles => List.unmodifiable(_vehicles);

  AdminStation? stationById(int? id) {
    if (id == null) return null;
    for (final s in _stations) {
      if (s.stationId == id) return s;
    }
    return null;
  }

  // ------------------------------------------------------------ views
  /// = SELECT ... FROM v_station_availability WHERE station_id = ?
  StationAvailability availability(AdminStation s) {
    final parked = _vehicles.where((v) => v.stationId == s.stationId).toList();
    final avail = parked.where((v) => v.status == VehicleStatus.available);
    return StationAvailability(
      availableVehicles: avail.length,
      availableBikes: avail.where((v) => v.vehicleType == VehicleType.eBike).length,
      availableScooters:
          avail.where((v) => v.vehicleType == VehicleType.eScooter).length,
      occupiedSlots: parked.length,
      freeSlots: s.capacity - parked.length,
    );
  }

  /// = SELECT * FROM v_dashboard_summary
  DashboardSummary get summary {
    int count(VehicleStatus st) => _vehicles.where((v) => v.status == st).length;
    return DashboardSummary(
      totalStations: _stations.length,
      activeStations: _stations.where((s) => s.isActive).length,
      totalVehicles: _vehicles.length,
      availableVehicles: count(VehicleStatus.available),
      borrowedVehicles: count(VehicleStatus.borrowed),
      maintenanceVehicles: count(VehicleStatus.maintenance),
      unavailableVehicles: count(VehicleStatus.unavailable),
      lowBatteryVehicles: _vehicles
          .where((v) => v.lowBattery && v.status != VehicleStatus.unavailable)
          .length,
    );
  }

  // ------------------------------------------------------------ station CRUD
  /// Create – คืนค่า null ถ้าสำเร็จ, หรือข้อความ error
  String? addStation(AdminStation draft) {
    final err = _validateStation(draft);
    if (err != null) return err;
    _stations.add(AdminStation(
      stationId: _nextStationId++,
      stationName: draft.stationName,
      buildingName: draft.buildingName,
      description: draft.description,
      qrCode: draft.qrCode,
      capacity: draft.capacity,
      latitude: draft.latitude,
      longitude: draft.longitude,
      status: draft.status,
    ));
    notifyListeners();
    return null;
  }

  /// Update
  String? updateStation(AdminStation edited) {
    final err = _validateStation(edited, editingId: edited.stationId);
    if (err != null) return err;
    final i = _stations.indexWhere((s) => s.stationId == edited.stationId);
    if (i < 0) return 'Station not found';
    _stations[i] = edited;
    notifyListeners();
    return null;
  }

  /// Delete = soft delete (Backend rule 6) → status = inactive
  void deactivateStation(int id) {
    stationById(id)?.status = StationStatus.inactive;
    notifyListeners();
  }

  void reactivateStation(int id) {
    stationById(id)?.status = StationStatus.active;
    notifyListeners();
  }

  String? _validateStation(AdminStation s, {int? editingId}) {
    if (s.stationName.trim().isEmpty) return 'Station name is required';
    if (s.buildingName.trim().isEmpty) return 'Building name is required';
    if (s.capacity < 1) return 'Capacity must be at least 1'; // chk_station_capacity
    final lat = s.latitude, lng = s.longitude;
    if (lat != null && (lat < -90 || lat > 90)) return 'Latitude must be -90 to 90';
    if (lng != null && (lng < -180 || lng > 180)) {
      return 'Longitude must be -180 to 180';
    }
    final qr = s.qrCode;
    if (qr != null &&
        _stations.any((o) => o.stationId != editingId && o.qrCode == qr)) {
      return 'QR code "$qr" is already used'; // qr_code UNIQUE
    }
    if (editingId != null) {
      final parked = _vehicles.where((v) => v.stationId == editingId).length;
      if (s.capacity < parked) {
        return 'Capacity cannot be less than $parked parked vehicles';
      }
    }
    return null;
  }

  // ------------------------------------------------------------ vehicle CRUD
  String? addVehicle(AdminVehicle draft) {
    final err = _validateVehicle(draft);
    if (err != null) return err;
    _vehicles.add(AdminVehicle(
      vehicleId: _nextVehicleId++,
      vehicleCode: draft.vehicleCode,
      qrCode: draft.qrCode,
      vehicleType: draft.vehicleType,
      stationId: draft.stationId,
      batteryLevel: draft.batteryLevel,
      status: draft.status,
    ));
    notifyListeners();
    return null;
  }

  String? updateVehicle(AdminVehicle edited) {
    final err = _validateVehicle(edited, editingId: edited.vehicleId);
    if (err != null) return err;
    final i = _vehicles.indexWhere((v) => v.vehicleId == edited.vehicleId);
    if (i < 0) return 'Vehicle not found';
    _vehicles[i] = edited;
    notifyListeners();
    return null;
  }

  /// เปลี่ยนสถานะเร็ว ๆ จากรายการ (พร้อมใช้ ↔ ส่งซ่อม)
  String? setVehicleStatus(AdminVehicle v, VehicleStatus status) {
    final copy = _copy(v)..status = status;
    return updateVehicle(copy);
  }

  /// Delete = soft delete (Backend rule 6) → status = unavailable
  String? retireVehicle(AdminVehicle v) {
    if (v.status == VehicleStatus.borrowed) {
      return 'Cannot remove a vehicle that is being borrowed';
    }
    return setVehicleStatus(v, VehicleStatus.unavailable);
  }

  String? _validateVehicle(AdminVehicle v, {int? editingId}) {
    if (v.vehicleCode.trim().isEmpty) return 'Vehicle code is required';
    if (v.qrCode.trim().isEmpty) return 'QR code is required';
    if (v.batteryLevel < 0 || v.batteryLevel > 100) {
      return 'Battery must be 0–100'; // chk_vehicle_battery
    }
    if (_vehicles.any((o) => o.vehicleId != editingId && o.vehicleCode == v.vehicleCode)) {
      return 'Vehicle code "${v.vehicleCode}" already exists';
    }
    if (_vehicles.any((o) => o.vehicleId != editingId && o.qrCode == v.qrCode)) {
      return 'QR code "${v.qrCode}" already exists';
    }
    // chk_vehicle_location
    final old = editingId == null
        ? null
        : _vehicles.firstWhere((o) => o.vehicleId == editingId);
    if (v.status == VehicleStatus.borrowed) {
      // admin ตั้งเป็น borrowed เองไม่ได้ – ระบบตั้งให้ตอนผู้ใช้ยืม (Backend rule 4)
      if (old?.status != VehicleStatus.borrowed) {
        return 'Borrowed status is set only by the borrow flow';
      }
      if (v.stationId != null) return 'A borrowed vehicle has no station';
    }
    if (v.status == VehicleStatus.available && v.stationId == null) {
      return 'An available vehicle must be parked at a station';
    }
    // ต้องมีช่องจอดว่างถ้าย้ายเข้าสถานีใหม่
    final st = stationById(v.stationId);
    if (st != null) {
      final movingIn = old == null || old.stationId != v.stationId;
      if (movingIn && availability(st).freeSlots <= 0) {
        return '${st.stationName} has no free docks';
      }
      if (v.status == VehicleStatus.available && !st.isActive) {
        return '${st.stationName} is inactive';
      }
    }
    return null;
  }

  AdminVehicle _copy(AdminVehicle v) => AdminVehicle(
        vehicleId: v.vehicleId,
        vehicleCode: v.vehicleCode,
        qrCode: v.qrCode,
        vehicleType: v.vehicleType,
        stationId: v.stationId,
        batteryLevel: v.batteryLevel,
        status: v.status,
      );

  // ------------------------------------------------------------ mock data
  /// ข้อมูลเดียวกับ SAMPLE DATA ในไฟล์ SQL (+ รถที่ถูกยืม 2 คันให้ dashboard มีตัวเลข)
  void _seed() {
    void st(String n, String b, String d, String qr, int cap, double la, double lo) =>
        _stations.add(AdminStation(
          stationId: _nextStationId++,
          stationName: n,
          buildingName: b,
          description: d,
          qrCode: qr,
          capacity: cap,
          latitude: la,
          longitude: lo,
        ));
    st('Library Station', 'Central Library', 'In front of the main entrance', 'STN-LIB', 6, 13.7563, 100.5018);
    st('Engineering Station', 'Engineering Building', 'Next to the parking area', 'STN-ENG', 8, 13.7571, 100.5030);
    st('Canteen Station', 'Main Canteen', 'Beside the east gate', 'STN-CAN', 6, 13.7555, 100.5042);
    st('Science Station', 'Science Building', 'Near the lobby', 'STN-SCI', 5, 13.7549, 100.5025);

    void vh(String code, int? stId, VehicleType t, int bat, VehicleStatus s) =>
        _vehicles.add(AdminVehicle(
          vehicleId: _nextVehicleId++,
          vehicleCode: code,
          qrCode: 'QR-$code',
          vehicleType: t,
          stationId: stId,
          batteryLevel: bat,
          status: s,
        ));
    const bk = VehicleType.eBike, sc = VehicleType.eScooter;
    const av = VehicleStatus.available;
    vh('EB-001', 1, bk, 95, av);
    vh('EB-002', 1, bk, 80, av);
    vh('ES-001', 1, sc, 70, av);
    vh('EB-003', 2, bk, 88, av);
    vh('ES-002', 2, sc, 100, av);
    vh('ES-003', 2, sc, 15, av);
    vh('EB-004', 3, bk, 60, av);
    vh('ES-004', 3, sc, 45, VehicleStatus.maintenance);
    vh('EB-005', 4, bk, 92, av);
    vh('ES-005', 4, sc, 55, VehicleStatus.unavailable);
    vh('EB-006', null, bk, 72, VehicleStatus.borrowed);
    vh('ES-006', null, sc, 64, VehicleStatus.borrowed);
  }
}
