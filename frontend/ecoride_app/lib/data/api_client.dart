// ApiClient – ตัวเรียก REST API ของ backend (Node.js/Express) ใช้ร่วมกันทั้งแอป
//
// ตั้งที่อยู่ backend ตอนรัน (ค่าเริ่มต้น http://localhost:3000):
//   flutter run -d chrome --dart-define=API_BASE=http://localhost:3000
//   Android emulator ใช้ http://10.0.2.2:3000 · มือถือจริงใช้ IP เครื่องในวง LAN
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const String kApiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3000');

/// error จาก backend ({ "error": "ข้อความ" }) หรือเชื่อมต่อไม่ได้ – message พร้อมโชว์ให้ผู้ใช้
class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status; // HTTP status (null = ติดต่อ server ไม่ได้)

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        baseUrl = baseUrl ?? kApiBase;

  final http.Client _http;
  final String baseUrl;

  /// JWT จาก POST /auth/login (ใส่ให้ทุก request ถัดไปอัตโนมัติ)
  String? token;

  Uri _uri(String path) => Uri.parse('$baseUrl/api$path');

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, _uri(path))..headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final t = token;
    if (t != null) req.headers['Authorization'] = 'Bearer $t';

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } on Exception {
      throw ApiException('Cannot reach the server. Please check your connection.');
    }

    dynamic data;
    if (res.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        data = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final msg = data is Map && data['error'] is String ? data['error'] as String : 'Server error (${res.statusCode})';
    throw ApiException(msg, res.statusCode);
  }

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body ?? const {});
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body ?? const {});
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// GET ที่คืน JSON object / array (cast ให้เลย)
  Future<Map<String, dynamic>> getMap(String path) async => (await get(path)) as Map<String, dynamic>;
  Future<List<Map<String, dynamic>>> getList(String path) async =>
      ((await get(path)) as List<dynamic>).cast<Map<String, dynamic>>();

  /// ดาวน์โหลดรูปที่ backend เก็บไว้ (เช่น /uploads/avatar-1-xxxx.png) – null ถ้าโหลดไม่ได้
  Future<Uint8List?> downloadImage(String urlPath) async {
    try {
      final res = await _http.get(Uri.parse('$baseUrl$urlPath')).timeout(const Duration(seconds: 20));
      return res.statusCode == 200 ? res.bodyBytes : null;
    } on Exception {
      return null;
    }
  }
}

/// เดา MIME ของรูปจาก byte แรกๆ (backend รับเฉพาะ png / jpeg / webp)
String sniffImageMime(Uint8List b) {
  if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length > 2 && b[0] == 0xFF && b[1] == 0xD8) return 'image/jpeg';
  if (b.length > 11 && b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57 && b[9] == 0x45) return 'image/webp';
  return 'application/octet-stream';
}
