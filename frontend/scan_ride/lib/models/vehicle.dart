enum VehicleType { ebike, scooter }

enum VehicleStatus { available, inUse, maintenance }

/// รถ 1 คัน (จักรยานไฟฟ้า / สกู๊ตเตอร์)
class Vehicle {
  final String id; // เช่น EB-012 (ค่าเดียวกับที่เก็บอยู่ใน QR)
  final VehicleType type;
  final int battery; // 0-100
  final VehicleStatus status;
  final String stationName;

  const Vehicle({
    required this.id,
    required this.type,
    required this.battery,
    required this.status,
    required this.stationName,
  });

  /// แบตต่ำกว่านี้ไม่ให้ยืม
  static const int minBattery = 15;

  String get typeLabel => type == VehicleType.ebike ? 'E-bike' : 'Scooter';

  /// เหตุผลที่ยืมไม่ได้ (null = ยืมได้)
  String? get blockReason {
    if (status == VehicleStatus.inUse) return 'This vehicle is already in use.';
    if (status == VehicleStatus.maintenance) {
      return 'This vehicle is under maintenance.';
    }
    if (battery < minBattery) return 'Battery too low to ride.';
    return null;
  }

  bool get canBorrow => blockReason == null;

  /// แปลงจาก JSON ของ backend (ชื่อ field ต้องตกลงกับคนทำ backend)
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      type: json['type'] == 'scooter' ? VehicleType.scooter : VehicleType.ebike,
      battery: (json['battery'] as num).toInt(),
      status: _statusFrom(json['status'] as String?),
      stationName: (json['station'] ?? '-') as String,
    );
  }

  static VehicleStatus _statusFrom(String? s) {
    switch (s) {
      case 'in_use':
        return VehicleStatus.inUse;
      case 'maintenance':
        return VehicleStatus.maintenance;
      default:
        return VehicleStatus.available;
    }
  }

  /// ดึงรหัสรถออกจากข้อความใน QR
  /// รองรับทั้ง "EB-012" และ "ecoride://vehicle/EB-012"
  static String codeFromQr(String raw) {
    final text = raw.trim();
    final last = text.contains('/') ? text.split('/').last : text;
    return last.trim().toUpperCase();
  }
}
