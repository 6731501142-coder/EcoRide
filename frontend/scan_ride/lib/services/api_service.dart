import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ride.dart';
import '../models/vehicle.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// จุดเดียวที่แอปคุยกับ backend
/// - useMock = true  -> ใช้ข้อมูลจำลอง (ทดสอบได้โดยยังไม่มี backend)
/// - useMock = false -> เรียก REST API จริงที่ baseUrl
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const bool useMock = true;
  static const String baseUrl = 'http://localhost:3000/api'; // แก้ตาม backend

  /// token ที่ได้จากหน้า Login (คนทำ Login ตั้งค่า: ApiService.instance.token = '...')
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ---------- ข้อมูลจำลอง (ใช้ตอน useMock = true) ----------
  static const Map<String, Vehicle> _mockVehicles = {
    'EB-012': Vehicle(
        id: 'EB-012',
        type: VehicleType.ebike,
        battery: 86,
        status: VehicleStatus.available,
        stationName: 'Library'),
    'ES-027': Vehicle(
        id: 'ES-027',
        type: VehicleType.scooter,
        battery: 54,
        status: VehicleStatus.available,
        stationName: 'Library'),
    'ES-031': Vehicle(
        id: 'ES-031',
        type: VehicleType.scooter,
        battery: 9, // แบตต่ำ -> ยืมไม่ได้ (ไว้ทดสอบ)
        status: VehicleStatus.available,
        stationName: 'Library'),
    'EB-020': Vehicle(
        id: 'EB-020',
        type: VehicleType.ebike,
        battery: 70,
        status: VehicleStatus.inUse, // มีคนใช้อยู่ (ไว้ทดสอบ)
        stationName: 'Building A'),
  };

  // ---------- 1) ดึงข้อมูลรถจากรหัสใน QR ----------
  // GET /vehicles/{code}
  Future<Vehicle> getVehicle(String code) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      final v = _mockVehicles[code];
      if (v == null) throw ApiException('Vehicle "$code" not found.');
      return v;
    }
    final res = await http.get(Uri.parse('$baseUrl/vehicles/$code'),
        headers: _headers);
    if (res.statusCode == 404) throw ApiException('Vehicle "$code" not found.');
    if (res.statusCode != 200) {
      throw ApiException('Server error (${res.statusCode}).');
    }
    return Vehicle.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ---------- 2) เริ่มการยืม ----------
  // POST /rides   body: {"vehicle_id": "EB-012"}
  Future<Ride> startRide(Vehicle vehicle) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      return Ride(
        id: 'R-${DateTime.now().millisecondsSinceEpoch}',
        vehicle: vehicle,
        startedAt: DateTime.now(),
        fromStation: vehicle.stationName,
      );
    }
    final res = await http.post(Uri.parse('$baseUrl/rides'),
        headers: _headers, body: jsonEncode({'vehicle_id': vehicle.id}));
    if (res.statusCode == 409) {
      throw ApiException('Someone else just borrowed this vehicle.');
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException('Cannot start ride (${res.statusCode}).');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return Ride(
      id: j['id'].toString(),
      vehicle: vehicle,
      startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
      fromStation: vehicle.stationName,
    );
  }

  // ---------- 3) สถานีใกล้เคียงที่แนะนำ (หน้า Active Riding) ----------
  // GET /stations/nearby
  Future<StationInfo> getNearbyStation() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return const StationInfo(name: 'Building A', freeDocks: 3);
    }
    final res = await http.get(Uri.parse('$baseUrl/stations/nearby'),
        headers: _headers);
    if (res.statusCode != 200) {
      throw ApiException('Server error (${res.statusCode}).');
    }
    return StationInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
