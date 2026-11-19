// AppStore – "Model/Controller" ฝั่งแอป เชื่อมกับ backend (REST API) แล้ว
//
// หลักการ: เก็บ "สำเนา" ข้อมูลล่าสุดจาก backend ไว้ในหน่วยความจำ (cache)
//   • getter / ฟังก์ชันอ่านข้อมูล (stations, myRides, liveBattery, availability …) ยังเป็น sync เหมือนเดิม
//     → หน้าจอที่แค่แสดงผลไม่ต้องแก้
//   • ฟังก์ชันที่เปลี่ยนข้อมูล (login, borrow, returnVehicle, confirmTopup …) เป็น Future:
//     เรียก API → สำเร็จแล้ว refresh() ดึงข้อมูลใหม่ → notifyListeners()
//   • ข้อความ error ที่คืนมาคือข้อความจาก backend (ตรงกับที่แอปเคยโชว์)
// กฎจริง (หักเครดิต, คืนรถ, เติมเงิน) ทำใน stored procedure ของ DB:
//   borrow() = sp_borrow_vehicle · returnVehicle() = sp_return_vehicle · confirmTopup() = sp_confirm_topup
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore(this.api);
  static final AppStore instance = AppStore(ApiClient()); // ใช้ร่วมกันทุกหน้า

  final ApiClient api;

  static const int minBattery = 20; // แบตขั้นต่ำที่ยืมได้
  static const double minTopup = 20, maxTopup = 5000; // เติมเงินต่อครั้ง

  /// เร่งเวลาจำลองแบต (1 = เวลาจริง) – ต้องตรงกับ BATTERY_TIME_SCALE ใน .env ของ backend
  static const double timeScale = 1;

  // ---------------------------------------------------------------- cache (สำเนาข้อมูลจาก backend)
  // User / Station / Vehicle เก็บเป็น Map ตาม id เพื่อให้ object เดิมถูกอัปเดตแทนที่จะสร้างใหม่
  // (หน้าจอที่ถือ object อยู่จะเห็นค่าใหม่ และ `==` ยังใช้ได้)
  final Map<int, User> _usersById = {};
  final Map<int, Station> _stationsById = {};
  final Map<int, Vehicle> _vehiclesById = {};
  List<VehicleType> _types = [];
  List<RentalPlan> _plans = [];
  List<Ride> _rides = [];
  List<Topup> _topups = [];
  List<CreditTransaction> _txns = [];
  List<ProblemReport> _reports = [];
  List<AppFeedback> _feedback = [];
  final Map<String, Uint8List> _images = {}; // url → รูปที่โหลดแล้ว (avatar / รูปสถานี)
  final Set<String> _loadingImages = {};

  List<User> get _users => _usersById.values.toList();
  List<Vehicle> get _vehicles => _vehiclesById.values.toList();
  List<Station> get _stations => _stationsById.values.toList();

  User? _me;
  User? get me => _me;

  // ตัวจับเวลา: ล็อกอินอยู่ → อัปเดตหน้าจอ (แบต ขี่/ชาร์จ, เวลา) ทุก 15 วินาที
  // และดึงข้อมูลใหม่จาก backend ทุก 60 วินาที (เห็นสิ่งที่คนอื่น/แอดมินเปลี่ยน)
  Timer? _ticker;
  int _tick = 0;
  void _startTicker() => _ticker ??= Timer.periodic(const Duration(seconds: 15), (_) {
        _tick++;
        if (_tick % 4 == 0) {
          refresh().catchError((_) {}); // เงียบ – ถ้า server ล่มก็แค่ใช้ข้อมูลเดิม
        } else {
          notifyListeners();
        }
      });

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _tick = 0;
  }

  /// ครอบการเรียก API: สำเร็จ → null, ล้มเหลว → ข้อความ error ให้โชว์ผู้ใช้
  Future<String?> _guard(Future<void> Function() body) async {
    try {
      await body();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e, st) {
      debugPrint('AppStore error: $e\n$st');
      return 'Something went wrong. Please try again.';
    }
  }

  // ================================================================ แบตเตอรี่ (จำลองให้ใกล้ชีวิตจริง)
  //
  // ▸ ตอนขี่: แบตลดตาม "ระยะทาง" ไม่ใช่เวลา (จอดเฉยๆ แบตแทบไม่ลด)
  //   แอปยังไม่มี GPS เลยประมาณระยะทาง = ชั่วโมงที่ "วิ่งจริง" × ความเร็วเฉลี่ย
  //   - ชั่วโมงแรก: สมมติวิ่งจริง 60% ของเวลา (ขี่ต่อเนื่องไปที่หมาย)
  //   - หลังจากนั้น: วิ่งจริงแค่ 10% (ส่วนใหญ่จอดเรียน/ทำธุระ ขี่เป็นช่วงสั้นๆ)
  //   แบตที่ใช้ = ระยะทาง × %ต่อกม. ของรถแต่ละประเภท
  //
  // ▸ ตอนจอดในสถานี: ทุกช่องจอดชาร์จไฟ
  //   ชาร์จเร็วถึง 80% แล้วช้าลงช่วง 80→100% (เหมือนแบตลิเธียมจริง)
  //   รถที่คืนมาแบต 0% ก็ชาร์จได้ปกติ ถึง 20% (ยืมได้) ภายในไม่ถึงชั่วโมง
  //
  // backend คำนวณสูตรเดียวกัน (src/services/batteryService.js) แอปใช้ค่าจาก backend เป็นจุดเริ่ม แล้วเดินต่อเองระหว่างรอ refresh

  /// ค่าคงที่ของรถแต่ละประเภท
  static ({double speedKmh, double pctPerKm, double fastPerHour, double slowPerHour}) specOf(
          VehicleType t) =>
      t.isBike
          // E-bike: ปั่นช่วยไฟ ~12 กม./ชม. ใช้แบต ~1.5%/กม. (วิ่งได้ ~65 กม.)
          //         ชาร์จ 0→80% ใน 3.5 ชม., 80→100% อีก 1.5 ชม.
          ? (speedKmh: 12, pctPerKm: 1.5, fastPerHour: 80 / 3.5, slowPerHour: 20 / 1.5)
          // E-scooter: ~15 กม./ชม. ใช้แบต ~3%/กม. (วิ่งได้ ~33 กม.)
          //         ชาร์จ 0→80% ใน 2.5 ชม., 80→100% อีก 1.5 ชม.
          : (speedKmh: 15, pctPerKm: 3.0, fastPerHour: 80 / 2.5, slowPerHour: 20 / 1.5);

  /// ระยะทางโดยประมาณ (กม.) ของการยืมที่ผ่านไป [used]
  double estimatedKm(Vehicle v, Duration used) {
    final h = used.inSeconds / 3600 * timeScale;
    final double movingHours = (h < 1 ? h : 1.0) * 0.6 + (h > 1 ? h - 1 : 0.0) * 0.1;
    return movingHours * specOf(typeOf(v)).speedKmh;
  }

  // แบต + เวลาที่เริ่มชาร์จ ของรถที่จอดอยู่ (ตั้งจาก live_battery ที่ backend ส่งมาทุกครั้งที่ refresh)
  final Map<int, (double, DateTime)> _chargeFrom = {};

  double _charged(VehicleType t, double from, Duration d) {
    final spec = specOf(t);
    var level = from;
    var h = d.inSeconds / 3600 * timeScale;
    if (level < 80) {
      final need = (80 - level) / spec.fastPerHour;
      if (h <= need) return level + h * spec.fastPerHour;
      level = 80;
      h -= need;
    }
    final full = level + h * spec.slowPerHour;
    return full > 100 ? 100 : full;
  }

  Ride? openRideOf(Vehicle v) {
    for (final r in _rides) {
      if (r.vehicleId == v.vehicleId && r.isOpen) return r;
    }
    return null;
  }

  /// แบตตอนนี้ของรถคันนี้
  int liveBattery(Vehicle v) {
    if (v.status == VehicleStatus.inUse) {
      final r = openRideOf(v);
      if (r == null) return v.batteryLevel;
      final used = estimatedKm(v, r.usedTime) * specOf(typeOf(v)).pctPerKm;
      return (r.batteryStart - used).clamp(0, 100).floor();
    }
    if (v.status == VehicleStatus.maintenance) return v.batteryLevel; // ซ่อมอยู่ ไม่ชาร์จ
    final c = _chargeFrom[v.vehicleId];
    if (c == null) return v.batteryLevel;
    return _charged(typeOf(v), c.$1, DateTime.now().difference(c.$2)).floor();
  }

  /// กำลังชาร์จอยู่ไหม (จอดอยู่และยังไม่เต็ม)
  bool isCharging(Vehicle v) =>
      v.status == VehicleStatus.available &&
      v.currentStationId != null &&
      liveBattery(v) < 100;

  /// อีกกี่นาทีแบตถึง 20% (ยืมได้) – null ถ้ายืมได้อยู่แล้ว
  int? minutesUntilReady(Vehicle v) {
    final now = liveBattery(v);
    if (now >= minBattery || !isCharging(v)) return null;
    final perHour = specOf(typeOf(v)).fastPerHour * timeScale;
    return ((minBattery - now) / perHour * 60).ceil();
  }

  /// จำนวนรถที่กำลังชาร์จ (ทุกสถานี)
  int get totalCharging => _vehicles.where(isCharging).length;

  // ================================================================ รูปโปรไฟล์ / รูปสถานี
  // อวาตาร์มี 2 แบบ (ใช้ได้ทีละแบบ): สำเร็จรูป (users.avatar_id) หรืออัปโหลดเอง (users.avatar_url)
  // รูปที่อัปโหลดจะถูกดาวน์โหลดมาเก็บเป็น bytes เพื่อให้ widget เดิม (Image.memory) ใช้ต่อได้
  int? get avatarId => _me?.avatarId;
  Uint8List? get avatarBytes {
    final url = _me?.avatarUrl;
    return url == null ? null : _images[url];
  }

  bool get hasAvatar => avatarId != null || avatarBytes != null;

  Future<String?> setPresetAvatar(int id) => _guard(() async {
        _applyUser(await api.put('/me/avatar', {'avatar_id': id}) as Map<String, dynamic>);
        notifyListeners();
      });

  /// bytes == null → ลบรูป (กลับไปใช้ตัวอักษรย่อ)
  Future<String?> setAvatar(Uint8List? bytes) => _guard(() async {
        final Map<String, dynamic> json;
        if (bytes == null) {
          json = await api.delete('/me/avatar') as Map<String, dynamic>;
        } else {
          json = await api.post('/me/avatar/photo', {
            'image_base64': base64Encode(bytes),
            'mime': sniffImageMime(bytes),
          }) as Map<String, dynamic>;
        }
        final u = _applyUser(json);
        if (u.avatarUrl != null && bytes != null) _images[u.avatarUrl!] = bytes; // ไม่ต้องโหลดซ้ำ
        notifyListeners();
      });

  /// ดาวน์โหลดรูปที่ backend เก็บไว้ (ครั้งเดียวต่อ url) แล้วแจ้งหน้าจอให้วาดใหม่
  void _ensureImage(String? url, [void Function(Uint8List bytes)? onLoaded]) {
    if (url == null) return;
    final cached = _images[url];
    if (cached != null) {
      onLoaded?.call(cached);
      return;
    }
    if (!_loadingImages.add(url)) return;
    api.downloadImage(url).then((bytes) {
      _loadingImages.remove(url);
      if (bytes == null) return;
      _images[url] = bytes;
      onLoaded?.call(bytes);
      notifyListeners();
    });
  }

  // ================================================================ auth
  /// Login – คืน null ถ้าสำเร็จ หรือข้อความ error (admin ก็ล็อกอินที่หน้านี้ → หน้า Login พาไปหน้า Admin ตาม role)
  Future<String?> login(String username, String password) => _guard(() async {
        final res = await api.post('/auth/login', {'username': username.trim(), 'password': password})
            as Map<String, dynamic>;
        api.token = res['token'] as String;
        try {
          _me = _applyUser(res['user'] as Map<String, dynamic>);
          await refresh();
        } catch (_) {
          _clear(); // โหลดข้อมูลไม่สำเร็จ → ไม่ค้างสถานะล็อกอินครึ่งๆ กลางๆ
          rethrow;
        }
        _startTicker();
        notifyListeners();
      });

  void logout() {
    _stopTicker();
    _clear();
    notifyListeners();
  }

  void _clear() {
    api.token = null;
    _me = null;
    _usersById.clear();
    _stationsById.clear();
    _vehiclesById.clear();
    _chargeFrom.clear();
    _types = [];
    _plans = [];
    _rides = [];
    _topups = [];
    _txns = [];
    _reports = [];
    _feedback = [];
  }

  Future<String?> register({
    required String fullName,
    required String studentId,
    required String username,
    required String password,
    required String confirm,
  }) =>
      _guard(() async {
        await api.post('/auth/register', {
          'full_name': fullName,
          'student_id': studentId,
          'username': username,
          'password': password,
          'confirm': confirm,
        });
      });

  /// Reset password: ยืนยันตัวตนด้วย username + student ID + full name ต้องตรงทั้ง 3 อย่าง
  Future<String?> resetPassword({
    required String username,
    required String studentId,
    required String fullName,
    required String password,
    required String confirm,
  }) =>
      _guard(() async {
        await api.post('/auth/reset-password', {
          'username': username,
          'student_id': studentId,
          'full_name': fullName,
          'password': password,
          'confirm': confirm,
        });
      });

  /// Forgot username: หา username จาก student ID + full name → (username, null) หรือ (null, error)
  Future<(String?, String?)> findUsername({required String studentId, required String fullName}) async {
    String? name;
    final err = await _guard(() async {
      final res = await api.post('/auth/find-username', {'student_id': studentId, 'full_name': fullName})
          as Map<String, dynamic>;
      name = res['username'] as String?;
    });
    return (err == null ? name : null, err);
  }

  Future<String?> updateProfile({
    required String fullName,
    required String studentId,
    required String username,
  }) =>
      _guard(() async {
        _applyUser(await api.put('/me', {'full_name': fullName, 'student_id': studentId, 'username': username})
            as Map<String, dynamic>);
        notifyListeners();
      });

  Future<String?> changePassword(String current, String password, String confirm) => _guard(() async {
        await api.put('/me/password', {'current': current, 'password': password, 'confirm': confirm});
      });

  // ================================================================ lookups (อ่านจาก cache)
  List<Station> get stations => _stations.where((s) => s.isActive).toList();
  List<RentalPlan> get plans => List.unmodifiable(_plans);
  RentalPlan get defaultPlan => _plans.first;

  Station stationById(int id) => _stationsById[id]!;
  Vehicle vehicleById(int id) => _vehiclesById[id]!;
  VehicleType typeOf(Vehicle v) => _types.firstWhere((t) => t.typeId == v.typeId);
  RentalPlan planById(int id) => _plans.firstWhere((p) => p.planId == id);

  /// ค้นจาก cache (รายการรถทั้งหมดถูกโหลดมาแล้ว) – ใช้ตอนพิมพ์/สแกนรหัสรถ
  Vehicle? vehicleByCode(String code) {
    for (final v in _vehicles) {
      if (v.code.toUpperCase() == code.trim().toUpperCase()) return v;
    }
    return null;
  }

  /// รถที่จอดอยู่ที่สถานีนี้ (ทุกสถานะ) เรียงพร้อมยืมก่อน
  List<Vehicle> vehiclesAt(int stationId) {
    final list = _vehicles.where((v) => v.currentStationId == stationId).toList();
    list.sort((a, b) {
      final ra = canBorrowVehicle(a) ? 0 : 1, rb = canBorrowVehicle(b) ? 0 : 1;
      if (ra != rb) return ra - rb;
      return liveBattery(b) - liveBattery(a);
    });
    return list;
  }

  bool canBorrowVehicle(Vehicle v) =>
      v.status == VehicleStatus.available && v.currentStationId != null && liveBattery(v) >= minBattery;

  /// = v_station_availability (คำนวณจากรถใน cache ด้วยแบตสด)
  StationAvailability availability(Station s) {
    final docked = _vehicles.where((v) => v.currentStationId == s.stationId).toList();
    final ready = docked.where(canBorrowVehicle);
    return StationAvailability(
      readyBikes: ready.where((v) => typeOf(v).isBike).length,
      readyScooters: ready.where((v) => !typeOf(v).isBike).length,
      docked: docked.length,
      freeDocks: s.totalDocks - docked.length,
    );
  }

  int get totalReady => stations.fold(0, (sum, s) => sum + availability(s).ready);

  /// การยืมที่ยังไม่คืนของฉัน (ยืมได้ทีละ 1 คัน)
  Ride? get activeRide {
    if (_me == null) return null;
    for (final r in _rides) {
      if (r.userId == _me!.userId && r.isOpen) return r;
    }
    return null;
  }

  /// = v_ride_history ของฉัน ใหม่สุดก่อน
  List<Ride> get myRides {
    if (_me == null) return [];
    return _rides.where((r) => r.userId == _me!.userId).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// = v_user_monthly_stats (เดือนปัจจุบัน)
  MonthlyStats get monthlyStats {
    final now = DateTime.now();
    final rides =
        myRides.where((r) => r.startTime.year == now.year && r.startTime.month == now.month).toList();
    return MonthlyStats(
      rides: rides.length,
      // รวมเวลาของรอบที่กำลังขี่อยู่ด้วย (นับถึงตอนนี้) จะได้เห็นตัวเลขขยับทันที
      // หมายเหตุ: view ใน DB นับเฉพาะรอบที่คืนแล้ว จึงบวกรอบที่ค้างเองแบบนี้
      minutes: rides.fold(0, (m, r) => m + r.usedTime.inMinutes),
      spent: rides.fold(0.0, (s, r) => s + r.pricePaid),
    );
  }

  List<CreditTransaction> get myTransactions {
    if (_me == null) return [];
    return _txns.where((t) => t.userId == _me!.userId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ================================================================ borrow / return
  /// = sp_borrow_vehicle – คืน (ride, null) ถ้าสำเร็จ หรือ (null, error)
  Future<(Ride?, String?)> borrow(Vehicle v, RentalPlan plan) async {
    Ride? ride;
    final err = await _guard(() async {
      final res = await api.post('/rides', {'vehicle_id': v.vehicleId, 'plan_id': plan.planId})
          as Map<String, dynamic>;
      final id = Ride.fromJson(res['ride'] as Map<String, dynamic>).rideId;
      await refresh();
      ride = _rides.firstWhere((r) => r.rideId == id);
    });
    return (err == null ? ride : null, err);
  }

  /// = sp_return_vehicle – คืนได้เฉพาะสถานีที่ยืมมา และสถานีต้องมีช่องว่าง
  /// แบตตอนคืน backend คำนวณเอง ([batteryEnd] เก็บไว้เพื่อให้ signature เดิมยังเรียกได้ แต่ไม่ถูกส่งไป)
  Future<String?> returnVehicle(Ride ride, Station station, {int? batteryEnd}) => _guard(() async {
        await api.post('/rides/${ride.rideId}/return', {'station_id': station.stationId});
        await refresh();
      });

  // ================================================================ credit
  /// สร้างรายการเติมเงิน (pending) → หน้าจอโชว์ QR → แล้วเรียก confirmTopup
  Future<(Topup?, String?)> createTopup(double amount) async {
    Topup? t;
    final err = await _guard(() async {
      t = Topup.fromJson(await api.post('/topups', {'amount': amount}) as Map<String, dynamic>);
    });
    return (err == null ? t : null, err);
  }

  /// = sp_confirm_topup – เรียกหลังจ่าย QR สำเร็จ (แอดมินใช้ปุ่มเดียวกันยืนยันแทนผู้ใช้ได้)
  Future<String?> confirmTopup(Topup t) => _guard(() async {
        final path = (_me?.isAdmin ?? false) ? '/admin/topups/${t.topupId}/confirm' : '/topups/${t.topupId}/confirm';
        final res = await api.post(path) as Map<String, dynamic>;
        final paid = Topup.fromJson(res['topup'] as Map<String, dynamic>);
        t
          ..status = paid.status
          ..paidAt = paid.paidAt;
        await refresh();
      });

  // ================================================================ help & feedback
  /// ปุ่ม "Need help?" ในหน้า Summary: แจ้งเจ้าหน้าที่ให้มาหาที่จุดเกิดเหตุ
  /// = INSERT INTO problem_reports (ผูก ride_id + vehicle_id ของการยืมนี้) – คืน (เลขคำขอ, null) หรือ (null, error)
  Future<(int?, String?)> requestHelp({
    required Ride ride,
    required HelpType type,
    required String location,
    String details = '',
  }) async {
    int? id;
    final err = await _guard(() async {
      final res = await api.post('/rides/${ride.rideId}/help', {
        'type': type.name,
        'location': location,
        'details': details,
      }) as Map<String, dynamic>;
      id = ProblemReport.fromJson(res).reportId;
    });
    return (err == null ? id : null, err);
  }

  /// เมนู "Report & feedback" ในหน้า Profile: แจ้งปัญหาแอป/ข้อเสนอแนะ ส่งถึง admin
  Future<String?> submitFeedback({required FeedbackTopic topic, required String message}) => _guard(() async {
        await api.post('/feedback', {'topic': topic.db, 'message': message});
      });

  /// ข้อความรายการใน Payment history: ค่ายืมโชว์รหัสรถเสมอ
  String txnLabel(CreditTransaction t) {
    if (t.rideId == null) return t.label;
    for (final r in _rides) {
      if (r.rideId == t.rideId) {
        final v = _vehiclesById[r.vehicleId];
        return v == null ? t.label : 'Ride · ${v.code}';
      }
    }
    return t.label;
  }

  // ================================================================ ฝั่ง Admin
  // หน้า admin (lib/admin/) ใช้ cache ชุดเดียวกัน: ผู้ใช้ยืม/คืน → Rides · กด Need help? → Issues ·
  // เติมเงิน → Top-ups · ส่ง feedback → Feedback  (แอดมินเห็นหลัง refresh ทุก 60 วินาทีหรือหลังกดอะไรสักอย่าง)

  List<Station> get allStations => List.unmodifiable(_stations); // รวมสถานีที่ปิดอยู่
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<VehicleType> get types => List.unmodifiable(_types);
  List<User> get students => _users.where((u) => !u.isAdmin).toList();
  User userById(int id) => _usersById[id]!;

  /// รอบที่ยังไม่คืน – เกินเวลาขึ้นก่อน
  List<Ride> get openRides => _rides.where((r) => r.isOpen).toList()
    ..sort((a, b) {
      if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
      return a.dueTime.compareTo(b.dueTime);
    });
  List<Ride> get overdueRides => openRides.where((r) => r.isOverdue).toList();
  List<Ride> get allRides => [..._rides]..sort((a, b) => b.startTime.compareTo(a.startTime));
  List<Ride> ridesOf(User u) => allRides.where((r) => r.userId == u.userId).toList();

  bool _thisMonth(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month;
  }

  /// รายได้เดือนนี้ = ค่ายืมที่ตัดเครดิตไปแล้ว (ride_payment) – เครดิตคงเหลือของผู้ใช้ไม่ใช่รายได้
  double get revenueThisMonth =>
      _txns.where((t) => t.txnType == 'ride_payment' && _thisMonth(t.createdAt)).fold(0.0, (s, t) => s - t.amount);

  double get topupsThisMonth => _topups
      .where((t) => t.status == TopupStatus.paid && t.paidAt != null && _thisMonth(t.paidAt!))
      .fold(0.0, (s, t) => s + t.amount);

  List<Topup> get pendingTopups => _topups.where((t) => t.status == TopupStatus.pending).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  List<Topup> get allTopups => [..._topups]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<CreditTransaction> txnsOf(User u) =>
      _txns.where((t) => t.userId == u.userId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// เงินไม่เข้า → topups.status = failed
  Future<String?> rejectTopup(Topup t) => _guard(() async {
        await api.post('/admin/topups/${t.topupId}/reject');
        t.status = TopupStatus.failed;
        await refresh();
      });

  /// ปรับเครดิต → credit_transactions (refund / adjustment)
  Future<String?> adjustCredit(User u, double amount, String reason, {bool refund = false}) => _guard(() async {
        await api.post('/admin/users/${u.userId}/credit', {'amount': amount, 'reason': reason, 'refund': refund});
        await refresh();
      });

  /// issue: ด่วนก่อน → ยังไม่ปิด → ใหม่ก่อน
  List<ProblemReport> get reports => [..._reports]..sort((a, b) {
      int rank(ProblemReport r) => r.status == 'resolved' ? 2 : (r.isUrgent ? 0 : 1);
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
  List<ProblemReport> get openReports => reports.where((r) => r.status != 'resolved').toList();
  List<ProblemReport> get urgentOpen => openReports.where((r) => r.isUrgent).toList();

  Future<String?> setReportStatus(ProblemReport r, String status) => _guard(() async {
        await api.put('/admin/reports/${r.reportId}/status', {'status': status});
        r
          ..status = status
          ..resolvedAt = status == 'resolved' ? DateTime.now() : null;
        notifyListeners();
        await refresh();
      });

  List<AppFeedback> get feedback => [..._feedback]..sort((a, b) {
      if ((a.status == 'resolved') != (b.status == 'resolved')) {
        return a.status == 'resolved' ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  int get unreadFeedback => _feedback.where((f) => f.status == 'open').length;

  Future<String?> setFeedbackStatus(AppFeedback f, String status) => _guard(() async {
        await api.put('/admin/feedback/${f.feedbackId}/status', {'status': status});
        f.status = status;
        notifyListeners();
        await refresh();
      });

  /// ส่งซ่อม / กลับมาให้บริการ (ห้ามตอนมีคนยืม)
  Future<String?> setMaintenance(Vehicle v, bool repair) => _guard(() async {
        await api.put('/admin/vehicles/${v.vehicleId}/maintenance', {'repair': repair});
        await refresh();
      });

  /// INSERT INTO vehicles (vehicle_code ต้องไม่ซ้ำ) – รหัส = <prefix>-<เลข 3 หลัก>
  Future<String?> addVehicle({required VehicleType type, required String number, required Station station}) =>
      _guard(() async {
        await api.post('/admin/vehicles', {
          'type_id': type.typeId,
          'number': number.trim(),
          'station_id': station.stationId,
        });
        await refresh();
      });

  /// เพิ่ม (s == null) หรือแก้สถานี
  Future<String?> saveStation(Station? s, {required String name, required int docks, required bool active}) =>
      _guard(() async {
        if (s == null) {
          await api.post('/admin/stations', {'name': name, 'total_docks': docks});
        } else {
          await api.put('/admin/stations/${s.stationId}', {'name': name, 'total_docks': docks, 'is_active': active});
        }
        await refresh();
      });

  /// เปลี่ยนรูปสถานี: ไอคอนสำเร็จรูป และ/หรือ รูปถ่าย (ผู้ใช้เห็นทันทีในหน้า Home / เลือกรถ)
  Future<String?> setStationLook(Station st, {String? iconKey, Uint8List? photo, bool removePhoto = false}) =>
      _guard(() async {
        if (iconKey != null && iconKey != st.iconKey) {
          await api.put('/admin/stations/${st.stationId}', {
            'name': st.name,
            'total_docks': st.totalDocks,
            'is_active': st.isActive,
            'icon_key': iconKey,
          });
        }
        if (photo != null) {
          await api.post('/admin/stations/${st.stationId}/photo', {
            'image_base64': base64Encode(photo),
            'mime': sniffImageMime(photo),
          });
        } else if (removePhoto) {
          await api.delete('/admin/stations/${st.stationId}/photo');
        }
        await refresh();
      });

  /// แก้ชื่อ / รหัสนักศึกษาแทนผู้ใช้ (หน้า Account settings ล็อกไว้)
  Future<String?> updateUser(User u, {required String fullName, required String studentId}) => _guard(() async {
        await api.put('/admin/users/${u.userId}', {'full_name': fullName, 'student_id': studentId});
        await refresh();
      });

  /// ระงับ / เปิดบัญชี (users.is_active)
  Future<String?> setUserActive(User u, bool active) => _guard(() async {
        await api.put('/admin/users/${u.userId}/active', {'active': active});
        await refresh();
      });

  // ================================================================ ดึงข้อมูลจาก backend
  /// โหลดข้อมูลทั้งหมดที่ role นี้ต้องใช้มาใส่ cache แล้วแจ้งหน้าจอ (เรียกหลังล็อกอิน หลังทุกการแก้ไข และทุก 60 วิ)
  Future<void> refresh() async {
    final me = _me;
    if (me == null) return;
    final isAdmin = me.isAdmin;
    final token = api.token;

    final common = await Future.wait<dynamic>([
      api.getMap('/me'),
      api.getList('/vehicle-types'),
      api.getList('/rental-plans'),
      api.getList(isAdmin ? '/admin/stations' : '/stations'),
      api.getList('/vehicles'),
      api.getList(isAdmin ? '/admin/rides' : '/rides'),
    ]);
    List<Map<String, dynamic>> txns, users = [], topups = [], reports = [], feedback = [];
    if (isAdmin) {
      final a = await Future.wait<dynamic>([
        api.getList('/admin/users'),
        api.getList('/admin/topups'),
        api.getList('/admin/transactions'),
        api.getList('/admin/reports'),
        api.getList('/admin/feedback'),
      ]);
      users = a[0] as List<Map<String, dynamic>>;
      topups = a[1] as List<Map<String, dynamic>>;
      txns = a[2] as List<Map<String, dynamic>>;
      reports = a[3] as List<Map<String, dynamic>>;
      feedback = a[4] as List<Map<String, dynamic>>;
    } else {
      txns = await api.getList('/credit/transactions');
    }

    if (api.token != token || _me == null) return; // ระหว่างรอมีการ logout → ทิ้งผลที่มาถึงช้า

    _applyUser(common[0] as Map<String, dynamic>);
    _types = (common[1] as List<Map<String, dynamic>>).map(VehicleType.fromJson).toList();
    _plans = (common[2] as List<Map<String, dynamic>>).map(RentalPlan.fromJson).toList();
    _syncStations(common[3] as List<Map<String, dynamic>>);
    _syncVehicles(common[4] as List<Map<String, dynamic>>);
    _rides = (common[5] as List<Map<String, dynamic>>).map(Ride.fromJson).toList();
    _txns = txns.map(CreditTransaction.fromJson).toList();
    if (isAdmin) {
      for (final j in users) {
        _applyUser(j);
      }
      _topups = topups.map(Topup.fromJson).toList();
      _reports = reports.map(ProblemReport.fromJson).toList();
      _feedback = feedback.map(AppFeedback.fromJson).toList();
    }
    notifyListeners();
  }

  /// สร้างหรืออัปเดต User ใน cache (object เดิมถูกแก้ค่าแทนการสร้างใหม่)
  User _applyUser(Map<String, dynamic> json) {
    final fresh = User.fromJson(json);
    final old = _usersById[fresh.userId];
    final u = old ?? (_usersById[fresh.userId] = fresh);
    if (old != null) {
      old
        ..studentId = fresh.studentId
        ..username = fresh.username
        ..fullName = fresh.fullName
        ..creditBalance = fresh.creditBalance
        ..isActive = fresh.isActive
        ..avatarId = fresh.avatarId
        ..avatarUrl = fresh.avatarUrl;
    }
    if (_me != null && _me!.userId == u.userId) {
      _me = u;
      _ensureImage(u.avatarUrl);
    } else if (_me == null && json['role'] != null) {
      _me = u; // ตอน login: ยังไม่มี _me
      _ensureImage(u.avatarUrl);
    }
    return u;
  }

  void _syncStations(List<Map<String, dynamic>> rows) {
    final ids = <int>{};
    for (final j in rows) {
      final fresh = Station.fromJson(j);
      ids.add(fresh.stationId);
      final old = _stationsById[fresh.stationId];
      final st = old ?? (_stationsById[fresh.stationId] = fresh);
      if (old != null) {
        old
          ..name = fresh.name
          ..totalDocks = fresh.totalDocks
          ..isActive = fresh.isActive
          ..iconKey = fresh.iconKey;
        if (old.photoUrl != fresh.photoUrl) {
          old
            ..photoUrl = fresh.photoUrl
            ..photo = null;
        }
      }
      if (st.photoUrl == null) {
        st.photo = null;
      } else if (st.photo == null) {
        final id = st.stationId;
        _ensureImage(st.photoUrl, (bytes) {
          final cur = _stationsById[id];
          if (cur != null && cur.photoUrl == st.photoUrl) cur.photo = bytes;
        });
      }
    }
    _stationsById.removeWhere((id, _) => !ids.contains(id));
  }

  /// รถทั้งหมดจาก GET /vehicles – ตั้งแบตเริ่มต้นให้การจำลองฝั่งแอปจาก live_battery ของ backend
  void _syncVehicles(List<Map<String, dynamic>> rows) {
    final ids = <int>{};
    final now = DateTime.now();
    for (final j in rows) {
      final fresh = Vehicle.fromJson(j);
      ids.add(fresh.vehicleId);
      final old = _vehiclesById[fresh.vehicleId];
      final v = old ?? (_vehiclesById[fresh.vehicleId] = fresh);
      if (old != null) {
        old
          ..currentStationId = fresh.currentStationId
          ..batteryLevel = fresh.batteryLevel
          ..status = fresh.status;
      }
      final live = j['live_battery'] == null ? v.batteryLevel : (j['live_battery'] as num).toInt();
      switch (v.status) {
        case VehicleStatus.available:
          v.batteryLevel = live;
          _chargeFrom[v.vehicleId] = (live.toDouble(), now); // จอดชาร์จ: นับต่อจากค่าสดของ backend
        case VehicleStatus.maintenance:
          v.batteryLevel = live; // ซ่อมอยู่ไม่ชาร์จ
          _chargeFrom.remove(v.vehicleId);
        case VehicleStatus.inUse:
          _chargeFrom.remove(v.vehicleId); // กำลังขี่: liveBattery() ใช้ batteryStart ของ ride + เวลาที่ผ่านไป
      }
    }
    _vehiclesById.removeWhere((id, _) => !ids.contains(id));
    _chargeFrom.removeWhere((id, _) => !ids.contains(id));
  }
}
