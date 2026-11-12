// Model ทุกตัว ชื่อฟิลด์ตรงกับคอลัมน์ใน ecoride_db.sql (9 ตาราง + 3 view)
// fromJson ใช้ชื่อคอลัมน์ตาม DB → ตอนต่อ API ส่ง JSON แถวจาก DB เข้ามาได้เลย
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

// ตัวช่วยแปลงค่าจาก MySQL (DECIMAL มักมาเป็น String, TINYINT(1) มาเป็น 0/1)
double _d(dynamic v) => v is num ? v.toDouble() : double.parse(v.toString());
int _i(dynamic v) => v is num ? v.toInt() : int.parse(v.toString());
int? _iN(dynamic v) => v == null ? null : _i(v);
bool _b(dynamic v) => v == true || v == 1 || v == '1';
DateTime _t(dynamic v) => DateTime.parse(v.toString());
DateTime? _tN(dynamic v) => v == null ? null : _t(v);

// ------------------------------------------------------------------ users
class User {
  User({
    required this.userId,
    required this.studentId,
    required this.username,
    required this.fullName,
    required this.creditBalance,
    this.role = 'student',
    this.isActive = true,
  });

  final int userId; // user_id
  String studentId; // student_id (unique)
  String username; // username (unique)
  String fullName; // full_name
  double creditBalance; // credit_balance
  final String role; // role: student / admin
  bool isActive; // is_active (แอดมินระงับบัญชีได้)
  // password_hash อยู่ฝั่ง backend เท่านั้น ไม่ส่งมาที่แอป

  bool get isAdmin => role == 'admin';

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
  }

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory User.fromJson(Map<String, dynamic> j) => User(
        userId: _i(j['user_id']),
        studentId: j['student_id'] as String,
        username: j['username'] as String,
        fullName: j['full_name'] as String,
        creditBalance: _d(j['credit_balance']),
        role: (j['role'] ?? 'student') as String,
        isActive: _b(j['is_active'] ?? 1),
      );
}

// ------------------------------------------------------------------ stations
class Station {
  Station({
    required this.stationId,
    required this.name,
    required this.totalDocks,
    this.latitude,
    this.longitude,
    this.isActive = true,
    this.iconKey = 'building',
    this.photo,
  });

  final int stationId; // station_id
  String name; // name  เช่น "Building 1" (แอดมินแก้ได้)
  int totalDocks; // total_docks
  final double? latitude; // latitude  (ยังเป็น NULL – แอปไม่ใช้แผนที่แล้ว)
  final double? longitude; // longitude
  bool isActive; // is_active (ปิดสถานีชั่วคราวได้)

  // รูปสถานี (แอดมินตั้ง ผู้ใช้เห็น) – ⚠️ ยังไม่มีใน DB เสนอเพิ่ม:
  //   stations.icon_key VARCHAR(20) DEFAULT 'building'   ← ไอคอนสำเร็จรูป
  //   stations.photo_url VARCHAR(255) NULL                ← รูปถ่ายจริง (ต้องมี API อัปโหลด)
  String iconKey; // icon_key
  Uint8List? photo; // ตอนนี้เก็บในหน่วยความจำ (แทน photo_url)

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        stationId: _i(j['station_id']),
        name: j['name'] as String,
        totalDocks: _i(j['total_docks']),
        latitude: j['latitude'] == null ? null : _d(j['latitude']),
        longitude: j['longitude'] == null ? null : _d(j['longitude']),
        isActive: _b(j['is_active'] ?? 1),
        iconKey: (j['icon_key'] ?? 'building') as String,
      );
}

/// 1 แถวของ VIEW v_station_availability
class StationAvailability {
  const StationAvailability({
    required this.readyBikes,
    required this.readyScooters,
    required this.docked,
    required this.freeDocks,
  });
  final int readyBikes; // พร้อมยืม (available + แบต ≥ 20%)
  final int readyScooters;
  final int docked; // vehicles_docked
  final int freeDocks; // free_docks

  int get ready => readyBikes + readyScooters; // ready_to_ride
  bool get full => freeDocks <= 0; // is_full
}

// ------------------------------------------------------------------ vehicle_types
class VehicleType {
  const VehicleType({required this.typeId, required this.codePrefix, required this.name});
  final int typeId; // type_id
  final String codePrefix; // code_prefix  EB / ES
  final String name; // name  Electric bicycle / Electric scooter

  bool get isBike => codePrefix == 'EB';
  IconData get icon => isBike ? TablerIcons.bike : TablerIcons.scooterElectric;

  factory VehicleType.fromJson(Map<String, dynamic> j) => VehicleType(
        typeId: _i(j['type_id']),
        codePrefix: j['code_prefix'] as String,
        name: j['name'] as String,
      );
}

// ------------------------------------------------------------------ vehicles
enum VehicleStatus { available, inUse, maintenance }

VehicleStatus vehicleStatusFromDb(String s) => switch (s) {
      'in_use' => VehicleStatus.inUse,
      'maintenance' => VehicleStatus.maintenance,
      _ => VehicleStatus.available,
    };

class Vehicle {
  Vehicle({
    required this.vehicleId,
    required this.code,
    required this.typeId,
    required this.batteryLevel,
    required this.status,
    this.currentStationId,
  });

  final int vehicleId; // vehicle_id
  final String code; // vehicle_code เช่น EB-012
  final int typeId; // type_id
  int? currentStationId; // current_station_id (NULL ขณะถูกยืม)
  int batteryLevel; // battery_level 0–100
  VehicleStatus status; // status: available / in_use / maintenance

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        vehicleId: _i(j['vehicle_id']),
        code: j['vehicle_code'] as String,
        typeId: _i(j['type_id']),
        currentStationId: _iN(j['current_station_id']),
        batteryLevel: _i(j['battery_level']),
        status: vehicleStatusFromDb(j['status'] as String),
      );
}

// ------------------------------------------------------------------ rental_plans
class RentalPlan {
  const RentalPlan({
    required this.planId,
    required this.name,
    required this.durationHours,
    required this.price,
    this.isActive = true,
  });
  final int planId; // plan_id
  final String name; // name  "1 day (24 hrs)"
  final int durationHours; // duration_hours  24
  final double price; // price  100.00
  final bool isActive; // is_active

  factory RentalPlan.fromJson(Map<String, dynamic> j) => RentalPlan(
        planId: _i(j['plan_id']),
        name: j['name'] as String,
        durationHours: _i(j['duration_hours']),
        price: _d(j['price']),
        isActive: _b(j['is_active'] ?? 1),
      );
}

// ------------------------------------------------------------------ rides
enum RideStatus { active, returned, overdue }

RideStatus rideStatusFromDb(String s) => switch (s) {
      'returned' => RideStatus.returned,
      'overdue' => RideStatus.overdue,
      _ => RideStatus.active,
    };

class Ride {
  Ride({
    required this.rideId,
    required this.userId,
    required this.vehicleId,
    required this.planId,
    required this.startStationId,
    required this.startTime,
    required this.dueTime,
    required this.pricePaid,
    required this.batteryStart,
    this.returnStationId,
    this.endTime,
    this.batteryEnd,
    this.status = RideStatus.active,
  });

  final int rideId; // ride_id
  final int userId; // user_id
  final int vehicleId; // vehicle_id
  final int planId; // plan_id
  final int startStationId; // start_station_id
  int? returnStationId; // return_station_id
  final DateTime startTime; // start_time
  final DateTime dueTime; // due_time = start_time + duration_hours
  DateTime? endTime; // end_time (NULL = ยังไม่คืน)
  final int batteryStart; // battery_start
  int? batteryEnd; // battery_end
  final double pricePaid; // price_paid
  RideStatus status; // status: active / returned / overdue

  bool get isOpen => status != RideStatus.returned;

  /// DB ยังไม่มี job เปลี่ยน status เป็น overdue ให้อัตโนมัติ จึงเช็กจากเวลาเพิ่มด้วย
  bool get isOverdue =>
      status == RideStatus.overdue || (isOpen && DateTime.now().isAfter(dueTime));

  Duration get usedTime => (endTime ?? DateTime.now()).difference(startTime);

  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
        rideId: _i(j['ride_id']),
        userId: _i(j['user_id']),
        vehicleId: _i(j['vehicle_id']),
        planId: _i(j['plan_id']),
        startStationId: _i(j['start_station_id']),
        returnStationId: _iN(j['return_station_id']),
        startTime: _t(j['start_time']),
        dueTime: _t(j['due_time']),
        endTime: _tN(j['end_time']),
        batteryStart: _i(j['battery_start']),
        batteryEnd: _iN(j['battery_end']),
        pricePaid: _d(j['price_paid']),
        status: rideStatusFromDb(j['status'] as String),
      );
}

// ------------------------------------------------------------------ topups
enum TopupStatus { pending, paid, failed, expired }

class Topup {
  Topup({
    required this.topupId,
    required this.userId,
    required this.amount,
    required this.createdAt,
    this.paymentMethod = 'qr',
    this.referenceCode,
    this.status = TopupStatus.pending,
    this.paidAt,
  });
  final int topupId; // topup_id
  final int userId; // user_id
  final double amount; // amount
  final String paymentMethod; // payment_method (default 'qr')
  final String? referenceCode; // reference_code (เลขอ้างอิงจากระบบจ่ายเงิน)
  TopupStatus status; // status: pending / paid / failed / expired
  final DateTime createdAt; // created_at
  DateTime? paidAt; // paid_at

  factory Topup.fromJson(Map<String, dynamic> j) => Topup(
        topupId: _i(j['topup_id']),
        userId: _i(j['user_id']),
        amount: _d(j['amount']),
        paymentMethod: (j['payment_method'] ?? 'qr') as String,
        referenceCode: j['reference_code'] as String?,
        status: TopupStatus.values.byName(j['status'] as String),
        createdAt: _t(j['created_at']),
        paidAt: _tN(j['paid_at']),
      );
}

// ------------------------------------------------------------------ credit_transactions
class CreditTransaction {
  CreditTransaction({
    required this.txnId,
    required this.userId,
    required this.txnType,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.rideId,
    this.topupId,
    this.note,
  });
  final int txnId; // txn_id
  final int userId; // user_id
  final String txnType; // txn_type: topup / ride_payment / refund / adjustment
  final double amount; // amount (+ เติมเงิน, − ค่ายืม)
  final double balanceAfter; // balance_after
  final int? rideId; // ride_id
  final int? topupId; // topup_id
  final String? note; // note เช่น "Top up", "Ride EB-012"
  final DateTime createdAt; // created_at

  bool get isTopup => txnType == 'topup';

  /// ข้อความที่โชว์ในหน้า Payment history
  String get label =>
      note ??
      switch (txnType) {
        'topup' => 'Top up',
        'ride_payment' => 'Ride payment',
        'refund' => 'Refund',
        _ => 'Adjustment',
      };

  factory CreditTransaction.fromJson(Map<String, dynamic> j) => CreditTransaction(
        txnId: _i(j['txn_id']),
        userId: _i(j['user_id']),
        txnType: j['txn_type'] as String,
        amount: _d(j['amount']),
        balanceAfter: _d(j['balance_after']),
        rideId: _iN(j['ride_id']),
        topupId: _iN(j['topup_id']),
        note: j['note'] as String?,
        createdAt: _t(j['created_at']),
      );
}

// ------------------------------------------------------------------ problem_reports
enum ReportCategory { brakesWheels, damagedPart, lowBattery, electrical, other }

extension ReportCategoryX on ReportCategory {
  String get label => switch (this) {
        ReportCategory.brakesWheels => 'Brakes / wheels',
        ReportCategory.damagedPart => 'Damaged part',
        ReportCategory.lowBattery => 'Low battery',
        ReportCategory.electrical => 'Electrical',
        ReportCategory.other => 'Other',
      };

  /// ค่าในคอลัมน์ category (enum ใน DB)
  String get db => switch (this) {
        ReportCategory.brakesWheels => 'brakes_wheels',
        ReportCategory.damagedPart => 'damaged_part',
        ReportCategory.lowBattery => 'low_battery',
        ReportCategory.electrical => 'electrical',
        ReportCategory.other => 'other',
      };
}

ReportCategory reportCategoryFromDb(String s) =>
    ReportCategory.values.firstWhere((c) => c.db == s, orElse: () => ReportCategory.other);

class ProblemReport {
  ProblemReport({
    required this.reportId,
    required this.userId,
    required this.vehicleId,
    required this.category,
    required this.createdAt,
    this.details,
    this.rideId,
    this.status = 'open',
    this.resolvedAt,
  });
  final int reportId; // report_id
  final int userId; // user_id
  final int vehicleId; // vehicle_id
  final int? rideId; // ride_id (ไม่บังคับ)
  final ReportCategory category; // category
  final String? details; // details
  String status; // status: open / in_progress / resolved

  /// คำขอความช่วยเหลือจากปุ่ม Need help? (ข้อความขึ้นต้น [URGENT])
  bool get isUrgent => (details ?? '').startsWith('[URGENT]');
  final DateTime createdAt; // created_at
  DateTime? resolvedAt; // resolved_at

  factory ProblemReport.fromJson(Map<String, dynamic> j) => ProblemReport(
        reportId: _i(j['report_id']),
        userId: _i(j['user_id']),
        vehicleId: _i(j['vehicle_id']),
        rideId: _iN(j['ride_id']),
        category: reportCategoryFromDb(j['category'] as String),
        details: j['details'] as String?,
        status: j['status'] as String,
        createdAt: _t(j['created_at']),
        resolvedAt: _tN(j['resolved_at']),
      );
}

/// เทียบเท่า VIEW v_user_monthly_stats
/// (rides_this_month, hours_total, spent_this_month – นับ ride ที่เริ่มในเดือนนี้)
class MonthlyStats {
  const MonthlyStats({required this.rides, required this.minutes, required this.spent});
  final int rides; // rides_this_month
  final int minutes; // hours_total × 60
  final double spent; // spent_this_month

  factory MonthlyStats.fromJson(Map<String, dynamic> j) => MonthlyStats(
        rides: _i(j['rides_this_month']),
        minutes: (_d(j['hours_total']) * 60).round(),
        spent: _d(j['spent_this_month']),
      );
}

// ------------------------------------------------------------------ ขอความช่วยเหลือฉุกเฉิน (หน้า Summary)
// เก็บลงตาราง problem_reports เดิม (ผูกกับ ride_id ที่กำลังยืม) โดยแปลงประเภทเป็น category ของ DB
enum HelpType { accident, flatTyre, brakes, damaged, battery, other }

extension HelpTypeX on HelpType {
  String get label => switch (this) {
        HelpType.accident => 'Accident',
        HelpType.flatTyre => 'Flat tyre',
        HelpType.brakes => 'Brakes not working',
        HelpType.damaged => 'Vehicle broken',
        HelpType.battery => 'Battery died',
        HelpType.other => 'Something else',
      };

  IconData get icon => switch (this) {
        HelpType.accident => TablerIcons.alertTriangle,
        HelpType.flatTyre => TablerIcons.bike,
        HelpType.brakes => TablerIcons.alertOctagon,
        HelpType.damaged => TablerIcons.tool,
        HelpType.battery => TablerIcons.batteryOff,
        HelpType.other => TablerIcons.dots,
      };

  /// แปลงเป็นค่าในคอลัมน์ problem_reports.category
  ReportCategory get category => switch (this) {
        HelpType.flatTyre || HelpType.brakes => ReportCategory.brakesWheels,
        HelpType.damaged => ReportCategory.damagedPart,
        HelpType.battery => ReportCategory.lowBattery,
        HelpType.accident || HelpType.other => ReportCategory.other,
      };
}

// ------------------------------------------------------------------ feedback เกี่ยวกับแอป (หน้า Profile)
// ⚠️ ยังไม่มีตารางใน DB → เสนอให้เพื่อนเพิ่ม:
//    app_feedback(feedback_id, user_id, topic, message, status, created_at)
enum FeedbackTopic { appBug, payment, account, suggestion, other }

extension FeedbackTopicX on FeedbackTopic {
  String get label => switch (this) {
        FeedbackTopic.appBug => 'App bug',
        FeedbackTopic.payment => 'Payment / credit',
        FeedbackTopic.account => 'Account',
        FeedbackTopic.suggestion => 'Suggestion',
        FeedbackTopic.other => 'Other',
      };

  String get db => switch (this) {
        FeedbackTopic.appBug => 'app_bug',
        FeedbackTopic.payment => 'payment',
        FeedbackTopic.account => 'account',
        FeedbackTopic.suggestion => 'suggestion',
        FeedbackTopic.other => 'other',
      };
}

class AppFeedback {
  AppFeedback({
    required this.feedbackId,
    required this.userId,
    required this.topic,
    required this.message,
    required this.createdAt,
    this.status = 'open',
  });
  final int feedbackId;
  final int userId;
  final FeedbackTopic topic;
  final String message;
  final DateTime createdAt;
  String status; // open / read / resolved
}
