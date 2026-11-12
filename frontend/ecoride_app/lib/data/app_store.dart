// AppStore – "Model/Controller" ฝั่ง User (ข้อมูล mock ในหน่วยความจำ)
// กฎทุกข้อเลียนแบบ stored procedure ในฐานข้อมูลของเพื่อน:
//   borrow()        = sp_borrow_vehicle(user_id, vehicle_id, plan_id, @ride_id)
//   returnVehicle() = sp_return_vehicle(ride_id, station_id, battery_end)
//   confirmTopup()  = sp_confirm_topup(topup_id)
// ตอนต่อ backend: เปลี่ยนเนื้อในฟังก์ชันให้เรียก API แทน หน้าจอไม่ต้องแก้
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore._() {
    _seed();
  }
  static final AppStore instance = AppStore._(); // ใช้ร่วมกันทุกหน้า

  static const int minBattery = 20; // แบตขั้นต่ำที่ยืมได้
  static const double minTopup = 20, maxTopup = 5000; // เติมเงินต่อครั้ง

  /// เร่งเวลาจำลองแบต (1 = เวลาจริง) – ตอนเดโมหน้าห้องตั้ง 30 จะเห็นแบตขยับเร็วขึ้น 30 เท่า
  static const double timeScale = 1;

  final List<User> _users = [];
  final Map<int, String> _passwords = {}; // mock เท่านั้น – backend จริงเก็บ hash
  final List<Station> _stations = [];
  final List<VehicleType> _types = [];
  final List<Vehicle> _vehicles = [];
  final List<RentalPlan> _plans = [];
  final List<Ride> _rides = [];
  final List<Topup> _topups = [];
  final List<CreditTransaction> _txns = [];
  final List<ProblemReport> _reports = [];
  int _nextUser = 1, _nextRide = 1, _nextTopup = 1, _nextTxn = 1, _nextReport = 1;

  User? _me;
  User? get me => _me;

  // ตัวจับเวลา: ล็อกอินอยู่ → ให้หน้าจออัปเดตแบต (ขี่/ชาร์จ) และเวลาทุก 15 วินาที
  Timer? _ticker;
  void _startTicker() =>
      _ticker ??= Timer.periodic(const Duration(seconds: 15), (_) => notifyListeners());

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
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
  // ของจริง: ตัวรถ (IoT) ส่งค่าแบตจริงให้ backend แล้วแอปดึงค่านั้นมาแสดงแทนการคำนวณนี้

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

  // แบต + เวลาที่เริ่มชาร์จ ของรถที่จอดอยู่ (ตอนต่อ backend: battery_level + updated_at)
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

  // รูปโปรไฟล์ มี 2 แบบ (ใช้ได้ทีละแบบ):
  //  1) อวาตาร์สำเร็จรูป → เก็บแค่เลข id (ถ้าจะเก็บจริงให้เพิ่ม users.avatar_id ใน DB)
  //  2) รูปที่อัปโหลดเอง → เก็บในหน่วยความจำ (ถ้าจะเก็บจริงต้องมี users.avatar_url + API อัปโหลด)
  final Map<int, int> _avatarIds = {};
  final Map<int, Uint8List> _avatars = {};
  int? get avatarId => _me == null ? null : _avatarIds[_me!.userId];
  Uint8List? get avatarBytes => _me == null ? null : _avatars[_me!.userId];
  bool get hasAvatar => avatarId != null || avatarBytes != null;

  void setPresetAvatar(int id) {
    final u = _me;
    if (u == null) return;
    _avatars.remove(u.userId);
    _avatarIds[u.userId] = id;
    notifyListeners();
  }

  void setAvatar(Uint8List? bytes) {
    final u = _me;
    if (u == null) return;
    _avatarIds.remove(u.userId);
    if (bytes == null) {
      _avatars.remove(u.userId);
    } else {
      _avatars[u.userId] = bytes;
    }
    notifyListeners();
  }

  // ================================================================ auth
  /// Login – คืน null ถ้าสำเร็จ หรือข้อความ error
  String? login(String username, String password) {
    final u = _userByUsername(username.trim());
    if (u == null || _passwords[u.userId] != password) {
      return 'Wrong username or password';
    }
    if (!u.isActive) return 'This account has been disabled';
    // admin ก็ล็อกอินที่หน้านี้ได้ → หน้า Login จะพาไปหน้า Admin เอง (ดู role)
    _me = u;
    _startTicker();
    notifyListeners();
    return null;
  }

  void logout() {
    _stopTicker();
    _me = null;
    notifyListeners();
  }

  String? register({
    required String fullName,
    required String studentId,
    required String username,
    required String password,
    required String confirm,
  }) {
    if ([fullName, studentId, username, password].any((s) => s.trim().isEmpty)) {
      return 'Please fill in every field';
    }
    final pwErr = _checkNewPassword(password, confirm);
    if (pwErr != null) return pwErr;
    if (_userByUsername(username.trim()) != null) return 'Username is already taken';
    if (_users.any((u) => u.studentId == studentId.trim())) {
      return 'Student ID is already registered';
    }
    final u = User(
      userId: _nextUser++,
      studentId: studentId.trim(),
      username: username.trim(),
      fullName: fullName.trim(),
      creditBalance: 0,
    );
    _users.add(u);
    _passwords[u.userId] = password;
    notifyListeners();
    return null;
  }

  /// Reset password: ยืนยันตัวตนด้วย username + student ID + full name ต้องตรงทั้ง 3 อย่าง
  String? resetPassword({
    required String username,
    required String studentId,
    required String fullName,
    required String password,
    required String confirm,
  }) {
    if ([username, studentId, fullName].any((s) => s.trim().isEmpty)) {
      return 'Please fill in every field';
    }
    final u = _userByUsername(username.trim());
    if (u == null ||
        u.studentId != studentId.trim() ||
        u.fullName.toLowerCase() != fullName.trim().toLowerCase()) {
      return 'Username, student ID and full name do not match';
    }
    final pwErr = _checkNewPassword(password, confirm);
    if (pwErr != null) return pwErr;
    _passwords[u.userId] = password;
    return null;
  }

  /// Forgot username: หา username จาก student ID + full name → (username, null) หรือ (null, error)
  (String?, String?) findUsername({required String studentId, required String fullName}) {
    if (studentId.trim().isEmpty || fullName.trim().isEmpty) {
      return (null, 'Please fill in every field');
    }
    for (final u in _users) {
      if (u.studentId == studentId.trim() &&
          u.fullName.toLowerCase() == fullName.trim().toLowerCase()) {
        return (u.username, null);
      }
    }
    return (null, 'No account matches this student ID and name');
  }

  String? updateProfile({
    required String fullName,
    required String studentId,
    required String username,
  }) {
    final u = _me!;
    if ([fullName, studentId, username].any((s) => s.trim().isEmpty)) {
      return 'Please fill in every field';
    }
    final other = _userByUsername(username.trim());
    if (other != null && other.userId != u.userId) return 'Username is already taken';
    if (_users.any((x) => x.userId != u.userId && x.studentId == studentId.trim())) {
      return 'Student ID is already registered';
    }
    u
      ..fullName = fullName.trim()
      ..studentId = studentId.trim()
      ..username = username.trim();
    notifyListeners();
    return null;
  }

  String? changePassword(String current, String password, String confirm) {
    final u = _me!;
    if (_passwords[u.userId] != current) return 'Current password is incorrect';
    final pwErr = _checkNewPassword(password, confirm);
    if (pwErr != null) return pwErr;
    _passwords[u.userId] = password;
    return null;
  }

  String? _checkNewPassword(String p, String c) {
    if (p.length < 8) return 'Password must be at least 8 characters';
    if (p != c) return 'Passwords do not match';
    return null;
  }

  User? _userByUsername(String name) {
    for (final u in _users) {
      if (u.username.toLowerCase() == name.toLowerCase()) return u;
    }
    return null;
  }

  // ================================================================ lookups
  List<Station> get stations => _stations.where((s) => s.isActive).toList();
  List<RentalPlan> get plans => List.unmodifiable(_plans);
  RentalPlan get defaultPlan => _plans.first;

  Station stationById(int id) => _stations.firstWhere((s) => s.stationId == id);
  Vehicle vehicleById(int id) => _vehicles.firstWhere((v) => v.vehicleId == id);
  VehicleType typeOf(Vehicle v) => _types.firstWhere((t) => t.typeId == v.typeId);
  RentalPlan planById(int id) => _plans.firstWhere((p) => p.planId == id);

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
      v.status == VehicleStatus.available &&
      v.currentStationId != null &&
      liveBattery(v) >= minBattery;

  /// = SELECT * FROM v_station_availability WHERE station_id = ?
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
    return _rides.where((r) => r.userId == _me!.userId).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// = v_user_monthly_stats (เดือนปัจจุบัน)
  MonthlyStats get monthlyStats {
    final now = DateTime.now();
    final rides = myRides
        .where((r) => r.startTime.year == now.year && r.startTime.month == now.month)
        .toList();
    return MonthlyStats(
      rides: rides.length,
      // รวมเวลาของรอบที่กำลังขี่อยู่ด้วย (นับถึงตอนนี้) จะได้เห็นตัวเลขขยับทันที
      // หมายเหตุ: view ใน DB นับเฉพาะรอบที่คืนแล้ว ถ้าต่อ backend ต้องบวกรอบที่ค้างเองแบบนี้
      minutes: rides.fold(0, (m, r) => m + r.usedTime.inMinutes),
      spent: rides.fold(0.0, (s, r) => s + r.pricePaid),
    );
  }

  List<CreditTransaction> get myTransactions {
    if (_me == null) return [];
    return _txns.where((t) => t.userId == _me!.userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ================================================================ borrow / return
  /// = sp_borrow_vehicle – คืน (ride, null) ถ้าสำเร็จ หรือ (null, error)
  (Ride?, String?) borrow(Vehicle v, RentalPlan plan) {
    final u = _me!;
    if (activeRide != null) return (null, 'You already have a vehicle out. Return it first.');
    if (v.status != VehicleStatus.available || v.currentStationId == null) {
      return (null, '${v.code} is not available');
    }
    final startBattery = liveBattery(v);
    if (startBattery < minBattery) {
      return (null, 'Battery is below $minBattery%. Please choose another vehicle.');
    }
    if (u.creditBalance < plan.price) return (null, 'Not enough credit. Please top up first.');

    final now = DateTime.now();
    final ride = Ride(
      rideId: _nextRide++,
      userId: u.userId,
      vehicleId: v.vehicleId,
      planId: plan.planId,
      startStationId: v.currentStationId!,
      startTime: now,
      dueTime: now.add(Duration(hours: plan.durationHours)),
      pricePaid: plan.price,
      batteryStart: startBattery,
    );
    _rides.add(ride);
    u.creditBalance -= plan.price; // หักเครดิต + ลงบัญชีในขั้นเดียว
    _txns.add(CreditTransaction(
      txnId: _nextTxn++,
      userId: u.userId,
      txnType: 'ride_payment',
      rideId: ride.rideId,
      amount: -plan.price,
      balanceAfter: u.creditBalance,
      createdAt: now,
      note: 'Ride ${v.code}',
    ));
    v
      ..status = VehicleStatus.inUse
      ..batteryLevel = startBattery
      ..currentStationId = null; // รถออกจากสถานี
    _chargeFrom.remove(v.vehicleId);
    notifyListeners();
    return (ride, null);
  }

  /// = sp_return_vehicle – คืนได้เฉพาะสถานีที่ยืมมา และสถานีต้องมีช่องว่าง
  String? returnVehicle(Ride ride, Station station, {int? batteryEnd}) {
    if (!ride.isOpen) return 'This ride is already finished';
    if (station.stationId != ride.startStationId) {
      return 'You can only return to ${stationById(ride.startStationId).name}';
    }
    if (availability(station).full) return '${station.name} is full';
    final v = vehicleById(ride.vehicleId);
    final int end = batteryEnd ?? liveBattery(v); // ส่งเป็น p_battery_end ให้ sp_return_vehicle
    ride
      ..status = RideStatus.returned
      ..returnStationId = station.stationId
      ..endTime = DateTime.now()
      ..batteryEnd = end;
    v
      ..status = VehicleStatus.available
      ..currentStationId = station.stationId
      ..batteryLevel = end;
    _chargeFrom[v.vehicleId] = (end.toDouble(), DateTime.now()); // เสียบชาร์จทันทีที่คืน
    notifyListeners();
    return null;
  }

  // ================================================================ credit
  Topup createTopup(double amount) {
    assert(amount >= minTopup && amount <= maxTopup);
    final t = Topup(
        topupId: _nextTopup++, userId: _me!.userId, amount: amount, createdAt: DateTime.now());
    _topups.add(t);
    return t;
  }

  /// = sp_confirm_topup – เรียกหลังจ่าย QR สำเร็จ
  String? confirmTopup(Topup t) {
    if (t.status != TopupStatus.pending) return 'Top-up not found or not pending';
    final u = _users.firstWhere((x) => x.userId == t.userId);
    t
      ..status = TopupStatus.paid
      ..paidAt = DateTime.now();
    u.creditBalance += t.amount;
    _txns.add(CreditTransaction(
      txnId: _nextTxn++,
      userId: u.userId,
      txnType: 'topup',
      topupId: t.topupId,
      amount: t.amount,
      balanceAfter: u.creditBalance,
      createdAt: t.paidAt!,
      note: 'Top up',
    ));
    notifyListeners();
    return null;
  }

  // ================================================================ help & feedback
  final List<AppFeedback> _feedback = [];
  int _nextFeedback = 1;

  /// ปุ่ม "Need help?" ในหน้า Summary: แจ้งเจ้าหน้าที่ให้มาหาที่จุดเกิดเหตุ
  /// = INSERT INTO problem_reports (ผูก ride_id + vehicle_id ของการยืมนี้)
  /// คืน (เลขคำขอ, null) หรือ (null, error)
  (int?, String?) requestHelp({
    required Ride ride,
    required HelpType type,
    required String location,
    String details = '',
  }) {
    if (!ride.isOpen) return (null, 'This ride is already finished');
    if (location.trim().isEmpty) return (null, 'Please tell staff where you are');
    final note = StringBuffer('[URGENT] ${type.label} · at: ${location.trim()}');
    if (details.trim().isNotEmpty) note.write(' · ${details.trim()}');
    final r = ProblemReport(
      reportId: _nextReport++,
      userId: _me!.userId,
      vehicleId: ride.vehicleId,
      rideId: ride.rideId,
      category: type.category,
      details: note.toString(),
      createdAt: DateTime.now(),
    );
    _reports.add(r);
    notifyListeners();
    return (r.reportId, null);
  }

  /// เมนู "Report & feedback" ในหน้า Profile: แจ้งปัญหาแอป/ข้อเสนอแนะ ส่งถึง admin
  String? submitFeedback({required FeedbackTopic topic, required String message}) {
    if (message.trim().length < 5) return 'Please tell us a bit more';
    _feedback.add(AppFeedback(
      feedbackId: _nextFeedback++,
      userId: _me!.userId,
      topic: topic,
      message: message.trim(),
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    return null;
  }

  /// ข้อความรายการใน Payment history: ค่ายืมโชว์รหัสรถเสมอ (sp_borrow_vehicle เขียน note แค่ "Ride payment")
  String txnLabel(CreditTransaction t) {
    if (t.rideId == null) return t.label;
    for (final r in _rides) {
      if (r.rideId == t.rideId) return 'Ride · ${vehicleById(r.vehicleId).code}';
    }
    return t.label;
  }

  // ================================================================ ฝั่ง Admin
  // หน้า admin (lib/admin/) ใช้ข้อมูลชุดเดียวกับฝั่งผู้ใช้ → ผู้ใช้กดอะไร แอดมินเห็นทันที
  //   ผู้ใช้ยืม/คืน → Rides · กด Need help? → Issues · เติมเงิน → Top-ups · ส่ง feedback → Feedback

  List<Station> get allStations => List.unmodifiable(_stations); // รวมสถานีที่ปิดอยู่
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<VehicleType> get types => List.unmodifiable(_types);
  List<User> get students => _users.where((u) => !u.isAdmin).toList();
  User userById(int id) => _users.firstWhere((u) => u.userId == id);

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
  double get revenueThisMonth => _txns
      .where((t) => t.txnType == 'ride_payment' && _thisMonth(t.createdAt))
      .fold(0.0, (s, t) => s - t.amount);

  double get topupsThisMonth => _topups
      .where((t) => t.status == TopupStatus.paid && t.paidAt != null && _thisMonth(t.paidAt!))
      .fold(0.0, (s, t) => s + t.amount);

  List<Topup> get pendingTopups => _topups.where((t) => t.status == TopupStatus.pending).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  List<Topup> get allTopups => [..._topups]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<CreditTransaction> txnsOf(User u) => _txns.where((t) => t.userId == u.userId).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// เงินไม่เข้า → topups.status = failed
  void rejectTopup(Topup t) {
    if (t.status != TopupStatus.pending) return;
    t.status = TopupStatus.failed;
    notifyListeners();
  }

  /// ปรับเครดิต → credit_transactions (refund / adjustment)
  String? adjustCredit(User u, double amount, String reason, {bool refund = false}) {
    if (amount == 0) return 'Amount cannot be 0';
    if (reason.trim().isEmpty) return 'Please give a reason';
    if (u.creditBalance + amount < 0) return 'Credit cannot go below ฿0';
    u.creditBalance += amount;
    _txns.add(CreditTransaction(
      txnId: _nextTxn++,
      userId: u.userId,
      txnType: refund ? 'refund' : 'adjustment',
      amount: amount,
      balanceAfter: u.creditBalance,
      note: reason.trim(),
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    return null;
  }

  /// issue: ด่วนก่อน → ยังไม่ปิด → ใหม่ก่อน
  List<ProblemReport> get reports => [..._reports]..sort((a, b) {
      int rank(ProblemReport r) => r.status == 'resolved' ? 2 : (r.isUrgent ? 0 : 1);
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
  List<ProblemReport> get openReports => reports.where((r) => r.status != 'resolved').toList();
  List<ProblemReport> get urgentOpen => openReports.where((r) => r.isUrgent).toList();

  void setReportStatus(ProblemReport r, String status) {
    r.status = status;
    r.resolvedAt = status == 'resolved' ? DateTime.now() : null;
    notifyListeners();
  }

  List<AppFeedback> get feedback => [..._feedback]..sort((a, b) {
      if ((a.status == 'resolved') != (b.status == 'resolved')) {
        return a.status == 'resolved' ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  int get unreadFeedback => _feedback.where((f) => f.status == 'open').length;

  void setFeedbackStatus(AppFeedback f, String status) {
    f.status = status;
    notifyListeners();
  }

  /// ส่งซ่อม / กลับมาให้บริการ (ห้ามตอนมีคนยืม)
  String? setMaintenance(Vehicle v, bool repair) {
    if (v.status == VehicleStatus.inUse) return 'Someone is riding this vehicle';
    if (repair) {
      v
        ..batteryLevel = liveBattery(v)
        ..status = VehicleStatus.maintenance;
      _chargeFrom.remove(v.vehicleId);
    } else {
      v.status = VehicleStatus.available;
      _chargeFrom[v.vehicleId] = (v.batteryLevel.toDouble(), DateTime.now());
    }
    notifyListeners();
    return null;
  }

  int _nextVehicle = 11, _nextStation = 4;

  /// INSERT INTO vehicles (vehicle_code ต้องไม่ซ้ำ)
  String? addVehicle({required VehicleType type, required String number, required Station station}) {
    final n = int.tryParse(number.trim());
    if (n == null || n <= 0 || n > 999) return 'Enter a number 1–999';
    final code = '${type.codePrefix}-${n.toString().padLeft(3, '0')}';
    if (_vehicles.any((v) => v.code == code)) return '$code already exists';
    if (availability(station).freeDocks <= 0) return '${station.name} is full';
    final v = Vehicle(
      vehicleId: _nextVehicle++,
      code: code,
      typeId: type.typeId,
      currentStationId: station.stationId,
      batteryLevel: 100,
      status: VehicleStatus.available,
    );
    _vehicles.add(v);
    _chargeFrom[v.vehicleId] = (100, DateTime.now());
    notifyListeners();
    return null;
  }

  String? saveStation(Station? s, {required String name, required int docks, required bool active}) {
    if (name.trim().isEmpty) return 'Station name is required';
    if (_stations.any((x) => x != s && x.name.toLowerCase() == name.trim().toLowerCase())) {
      return 'This name is already used';
    }
    if (docks < 1) return 'Docks must be at least 1';
    if (s == null) {
      _stations.add(Station(stationId: _nextStation++, name: name.trim(), totalDocks: docks));
    } else {
      // ปิดสถานีไม่ได้ ถ้ายังมีคนยืมรถจากที่นี่ (ต้องคืนที่สถานีเดิม)
      if (!active && _rides.any((r) => r.isOpen && r.startStationId == s.stationId)) {
        return 'Riders still need to return vehicles here';
      }
      final parked = _vehicles.where((v) => v.currentStationId == s.stationId).length;
      if (docks < parked) return '$parked vehicles are parked here – need at least $parked docks';
      s
        ..name = name.trim()
        ..totalDocks = docks
        ..isActive = active;
    }
    notifyListeners();
    return null;
  }

  /// เปลี่ยนรูปสถานี: ไอคอนสำเร็จรูป และ/หรือ รูปถ่าย (ผู้ใช้เห็นทันทีในหน้า Home / เลือกรถ)
  void setStationLook(Station st, {String? iconKey, Uint8List? photo, bool removePhoto = false}) {
    if (iconKey != null) st.iconKey = iconKey;
    if (photo != null) st.photo = photo;
    if (removePhoto) st.photo = null;
    notifyListeners();
  }

  /// แก้ชื่อ / รหัสนักศึกษาแทนผู้ใช้ (หน้า Account settings ล็อกไว้)
  String? updateUser(User u, {required String fullName, required String studentId}) {
    if (fullName.trim().isEmpty || studentId.trim().isEmpty) return 'Please fill in every field';
    if (_users.any((x) => x != u && x.studentId == studentId.trim())) {
      return 'This student ID is already used';
    }
    u
      ..fullName = fullName.trim()
      ..studentId = studentId.trim();
    notifyListeners();
    return null;
  }

  /// ระงับ / เปิดบัญชี (users.is_active)
  String? setUserActive(User u, bool active) {
    if (!active && _rides.any((r) => r.userId == u.userId && r.isOpen)) {
      return 'This user still has a vehicle out';
    }
    u.isActive = active;
    notifyListeners();
    return null;
  }

  // ================================================================ mock data
  // คัดลอกจาก ecoride_db.sql (dump วันที่ 7 Nov 2026) ให้หน้าจอเห็นข้อมูลชุดเดียวกับ DB จริง
  void _seed() {
    DateTime t(String s) => DateTime.parse(s);

    _stations.addAll([
      Station(stationId: 1, name: 'Building 1', totalDocks: 10),
      Station(stationId: 2, name: 'Building 2', totalDocks: 12),
      Station(stationId: 3, name: 'Building 3', totalDocks: 10),
    ]);
    _types.addAll(const [
      VehicleType(typeId: 1, codePrefix: 'EB', name: 'Electric bicycle'),
      VehicleType(typeId: 2, codePrefix: 'ES', name: 'Electric scooter'),
    ]);
    _plans.add(const RentalPlan(planId: 1, name: '1 day (24 hrs)', durationHours: 24, price: 100));

    void vh(int id, String code, int type, int? st, int bat,
        [VehicleStatus status = VehicleStatus.available]) {
      _vehicles.add(Vehicle(
          vehicleId: id,
          code: code,
          typeId: type,
          currentStationId: st,
          batteryLevel: bat,
          status: status));
      // รถที่จอดอยู่เสียบชาร์จ เริ่มนับจากตอนเปิดแอป
      if (status == VehicleStatus.available) _chargeFrom[id] = (bat.toDouble(), DateTime.now());
    }

    vh(1, 'EB-012', 1, 1, 79);
    vh(2, 'EB-015', 1, 1, 72);
    vh(3, 'ES-031', 2, 1, 12);
    vh(4, 'ES-016', 2, 1, 91);
    vh(5, 'EB-021', 1, 2, 95);
    vh(6, 'ES-027', 2, null, 54, VehicleStatus.inUse); // ★ Krittin กำลังยืม
    vh(7, 'ES-022', 2, 2, 80);
    vh(8, 'EB-004', 1, null, 77, VehicleStatus.inUse); // ★ Malee ยืมเกินเวลา
    vh(9, 'EB-005', 1, 3, 88);
    vh(10, 'ES-041', 2, 3, 60);

    // users – password_hash ใน DB ยังเป็น placeholder จึงตั้งรหัสทดลองเป็น password123 ทั้งคู่
    final me = User(
        userId: 1,
        studentId: '6731501118',
        username: 'somchai.j',
        fullName: 'Somchai Jaidee',
        creditBalance: 150);
    final admin = User(
        userId: 2,
        studentId: 'ADMIN0001',
        username: 'admin',
        fullName: 'EcoRide Admin',
        creditBalance: 0,
        role: 'admin');
    _users.addAll([me, admin]);
    _passwords[1] = 'password123';
    _passwords[2] = 'password123';

    void top(int id, double amt, String created, String paid) => _topups.add(Topup(
        topupId: id,
        userId: 1,
        amount: amt,
        createdAt: t(created),
        status: TopupStatus.paid,
        paidAt: t(paid)));
    top(1, 100, '2026-10-28 10:00:00', '2026-10-28 10:00:30');
    top(2, 250, '2026-11-01 10:30:00', '2026-11-01 10:30:30');
    top(3, 200, '2026-11-04 20:05:00', '2026-11-04 20:05:30');

    void ride(int id, int veh, int st, String start, String due, String end, int b0, int b1) =>
        _rides.add(Ride(
            rideId: id,
            userId: 1,
            vehicleId: veh,
            planId: 1,
            startStationId: st,
            returnStationId: st,
            startTime: t(start),
            dueTime: t(due),
            endTime: t(end),
            batteryStart: b0,
            batteryEnd: b1,
            pricePaid: 100,
            status: RideStatus.returned));
    ride(1, 8, 3, '2026-10-29 08:05:00', '2026-10-30 08:05:00', '2026-10-29 08:41:00', 90, 77);
    ride(2, 6, 2, '2026-11-03 13:10:00', '2026-11-04 13:10:00', '2026-11-03 14:02:00', 70, 54);
    ride(3, 1, 1, '2026-11-05 09:42:00', '2026-11-06 09:42:00', '2026-11-05 10:05:00', 92, 86);
    ride(4, 1, 1, '2026-11-08 01:20:28', '2026-11-09 01:20:28', '2026-11-08 01:22:54', 86, 79);

    void txn(int id, String type, double amt, double bal, int? rideId, int? topupId,
            String note, String at) =>
        _txns.add(CreditTransaction(
            txnId: id,
            userId: 1,
            txnType: type,
            amount: amt,
            balanceAfter: bal,
            rideId: rideId,
            topupId: topupId,
            note: note,
            createdAt: t(at)));
    txn(1, 'topup', 100, 100, null, 1, 'Top up', '2026-10-28 10:00:30');
    txn(2, 'ride_payment', -100, 0, 1, null, 'Ride EB-004', '2026-10-29 08:05:00');
    txn(3, 'topup', 250, 250, null, 2, 'Top up', '2026-11-01 10:30:30');
    txn(4, 'ride_payment', -100, 150, 2, null, 'Ride ES-027', '2026-11-03 13:10:00');
    txn(5, 'topup', 200, 350, null, 3, 'Top up', '2026-11-04 20:05:30');
    txn(6, 'ride_payment', -100, 250, 3, null, 'Ride EB-012', '2026-11-05 09:42:00');
    txn(7, 'ride_payment', -100, 150, 4, null, 'Ride payment', '2026-11-08 01:20:28');

    _reports.add(ProblemReport(
        reportId: 1,
        userId: 1,
        vehicleId: 3,
        category: ReportCategory.lowBattery,
        details: 'Battery drains very quickly',
        createdAt: t('2026-11-08 01:13:18')));

    // ---------------- ★ ข้อมูลเพิ่มเพื่อเดโมหน้า Admin (ไม่มีใน dump)
    final now = DateTime.now();
    _users.addAll([
      User(userId: 3, studentId: '6731502229', username: 'malee.r',
          fullName: 'Malee Ratanachai', creditBalance: 40),
      User(userId: 4, studentId: '6731501086', username: 'krittin.w',
          fullName: 'Krittin Wong', creditBalance: 150),
    ]);
    _passwords[3] = 'password123';
    _passwords[4] = 'password123';

    _topups.addAll([
      Topup(topupId: 4, userId: 4, amount: 250, createdAt: t('2026-11-02 09:00:00'),
          status: TopupStatus.paid, paidAt: t('2026-11-02 09:00:40')),
      // รอแอดมินยืนยัน (เช่น โอนแล้วแต่ระบบยังไม่ตรวจเจอ)
      Topup(topupId: 5, userId: 3, amount: 200,
          createdAt: now.subtract(const Duration(minutes: 12))),
    ]);

    Ride open(int id, int userId, int veh, int st, Duration ago, int b0) {
      final start = now.subtract(ago);
      return Ride(
          rideId: id,
          userId: userId,
          vehicleId: veh,
          planId: 1,
          startStationId: st,
          startTime: start,
          dueTime: start.add(const Duration(hours: 24)),
          batteryStart: b0,
          pricePaid: 100);
    }

    _rides.add(open(5, 4, 6, 2, const Duration(minutes: 40), 54));
    _rides.add(open(6, 3, 8, 3, const Duration(hours: 26), 77)..status = RideStatus.overdue);

    _txns.addAll([
      CreditTransaction(txnId: 101, userId: 4, txnType: 'topup', amount: 250,
          balanceAfter: 250, topupId: 4, note: 'Top up', createdAt: t('2026-11-02 09:00:40')),
      CreditTransaction(txnId: 102, userId: 4, txnType: 'ride_payment', amount: -100,
          balanceAfter: 150, rideId: 5, note: 'Ride payment',
          createdAt: now.subtract(const Duration(minutes: 40))),
      CreditTransaction(txnId: 103, userId: 3, txnType: 'ride_payment', amount: -100,
          balanceAfter: 40, rideId: 6, note: 'Ride payment',
          createdAt: now.subtract(const Duration(hours: 26))),
    ]);

    _reports.add(ProblemReport(
        reportId: 2,
        userId: 4,
        vehicleId: 6,
        rideId: 5,
        category: ReportCategory.brakesWheels,
        details: '[URGENT] Flat tyre · at: in front of Building 2, near the canteen',
        createdAt: now.subtract(const Duration(minutes: 6))));

    _feedback.addAll([
      AppFeedback(feedbackId: 1, userId: 3, topic: FeedbackTopic.payment,
          message: 'I paid by QR but my credit took a long time to show up.',
          createdAt: now.subtract(const Duration(hours: 3))),
      AppFeedback(feedbackId: 2, userId: 1, topic: FeedbackTopic.suggestion,
          message: 'Could you add a station near the library?',
          createdAt: t('2026-11-07 18:20:00'), status: 'read'),
    ]);

    // id ถัดไป (เหมือน AUTO_INCREMENT)
    _nextUser = 5;
    _nextRide = 7;
    _nextTopup = 6;
    _nextTxn = 8; // (★ ใช้เลข 101+ จะได้ไม่ชนกัน)
    _nextReport = 3;
    _nextFeedback = 3;
  }
}
