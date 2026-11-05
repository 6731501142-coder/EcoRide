import 'vehicle.dart';

/// การยืม 1 ครั้ง (เริ่มตอนกด Confirm borrow)
class Ride {
  final String id;
  final Vehicle vehicle;
  final DateTime startedAt;
  final String fromStation;

  const Ride({
    required this.id,
    required this.vehicle,
    required this.startedAt,
    required this.fromStation,
  });
}

/// สถานีใกล้เคียงที่แนะนำให้ไปคืน
class StationInfo {
  final String name;
  final int freeDocks;

  const StationInfo({required this.name, required this.freeDocks});

  factory StationInfo.fromJson(Map<String, dynamic> json) => StationInfo(
        name: json['name'] as String,
        freeDocks: (json['free_docks'] as num).toInt(),
      );
}
