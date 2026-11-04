// โมเดลฝั่ง Admin – ชื่อฟิลด์ตรงกับตารางใน ecoride_backend_schema_v2.sql
// (stations, vehicles) เพื่อให้ Sprint 3 เปลี่ยนจาก mock ไปเรียก API ได้ง่าย
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

// ---------------------------------------------------------------- stations
enum StationStatus { active, inactive }

class AdminStation {
  AdminStation({
    required this.stationId,
    required this.stationName,
    required this.buildingName,
    required this.capacity,
    this.description,
    this.qrCode,
    this.latitude,
    this.longitude,
    this.status = StationStatus.active,
  });

  final int stationId; // station_id (PK)
  String stationName; // station_name
  String buildingName; // building_name
  String? description; // description
  String? qrCode; // qr_code – สแกนตอนคืนรถ
  int capacity; // capacity – จำนวนช่องจอดทั้งหมด (>= 1)
  double? latitude;
  double? longitude;
  StationStatus status; // active / inactive (inactive = soft delete)

  bool get isActive => status == StationStatus.active;

  /// แปลงจาก JSON ที่ backend ส่งมา (ใช้ใน Sprint 3)
  factory AdminStation.fromJson(Map<String, dynamic> j) => AdminStation(
        stationId: j['station_id'] as int,
        stationName: j['station_name'] as String,
        buildingName: j['building_name'] as String,
        description: j['description'] as String?,
        qrCode: j['qr_code'] as String?,
        capacity: j['capacity'] as int,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        status: j['status'] == 'inactive'
            ? StationStatus.inactive
            : StationStatus.active,
      );

  Map<String, dynamic> toJson() => {
        'station_name': stationName,
        'building_name': buildingName,
        'description': description,
        'qr_code': qrCode,
        'capacity': capacity,
        'latitude': latitude,
        'longitude': longitude,
        'status': status.name,
      };
}

// ---------------------------------------------------------------- vehicles
enum VehicleType {
  eBike('e_bike'),
  eScooter('e_scooter');

  const VehicleType(this.db);
  final String db; // ค่าที่เก็บในคอลัมน์ vehicle_type

  static VehicleType fromDb(String v) =>
      values.firstWhere((t) => t.db == v, orElse: () => eBike);
}

enum VehicleStatus { available, borrowed, maintenance, unavailable }

extension VehicleTypeX on VehicleType {
  String get label => this == VehicleType.eBike ? 'E-bike' : 'E-scooter';
  IconData get icon =>
      this == VehicleType.eBike ? TablerIcons.bike : TablerIcons.scooterElectric;
}

extension VehicleStatusX on VehicleStatus {
  String get label => switch (this) {
        VehicleStatus.available => 'Available',
        VehicleStatus.borrowed => 'Borrowed',
        VehicleStatus.maintenance => 'Maintenance',
        VehicleStatus.unavailable => 'Unavailable',
      };
}

class AdminVehicle {
  AdminVehicle({
    required this.vehicleId,
    required this.vehicleCode,
    required this.qrCode,
    required this.vehicleType,
    this.stationId,
    this.batteryLevel = 100,
    this.status = VehicleStatus.available,
  });

  final int vehicleId; // vehicle_id (PK)
  String vehicleCode; // vehicle_code เช่น EB-001
  String qrCode; // qr_code ติดที่ตัวรถ
  VehicleType vehicleType; // eBike / eScooter (DB: e_bike / e_scooter)
  int? stationId; // NULL ขณะถูกยืม
  int batteryLevel; // 0–100
  VehicleStatus status;

  bool get lowBattery => batteryLevel < 20; // MIN_BATTERY ใน backend rule 4

  factory AdminVehicle.fromJson(Map<String, dynamic> j) => AdminVehicle(
        vehicleId: j['vehicle_id'] as int,
        vehicleCode: j['vehicle_code'] as String,
        qrCode: j['qr_code'] as String,
        vehicleType: VehicleType.fromDb(j['vehicle_type'] as String),
        stationId: j['station_id'] as int?,
        batteryLevel: j['battery_level'] as int,
        status: VehicleStatus.values.byName(j['status'] as String),
      );

  Map<String, dynamic> toJson() => {
        'vehicle_code': vehicleCode,
        'qr_code': qrCode,
        'vehicle_type': vehicleType.db,
        'station_id': stationId,
        'battery_level': batteryLevel,
        'status': status.name,
      };
}

// ---------------------------------------------------------------- views
/// เทียบเท่า 1 แถวของ VIEW v_station_availability
class StationAvailability {
  const StationAvailability({
    required this.availableVehicles,
    required this.availableBikes,
    required this.availableScooters,
    required this.occupiedSlots,
    required this.freeSlots,
  });
  final int availableVehicles;
  final int availableBikes;
  final int availableScooters;
  final int occupiedSlots; // รถทุกคันที่จอดอยู่ (available+maintenance+unavailable)
  final int freeSlots; // capacity - occupiedSlots
}

/// เทียบเท่า VIEW v_dashboard_summary
class DashboardSummary {
  const DashboardSummary({
    required this.totalStations,
    required this.activeStations,
    required this.totalVehicles,
    required this.availableVehicles,
    required this.borrowedVehicles,
    required this.maintenanceVehicles,
    required this.unavailableVehicles,
    required this.lowBatteryVehicles,
  });
  final int totalStations;
  final int activeStations;
  final int totalVehicles;
  final int availableVehicles;
  final int borrowedVehicles;
  final int maintenanceVehicles;
  final int unavailableVehicles;
  final int lowBatteryVehicles; // รถที่ต้องชาร์จ (แบต < 20%)
}
