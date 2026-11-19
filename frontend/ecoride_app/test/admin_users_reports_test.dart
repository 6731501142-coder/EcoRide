// =============================================================================
// Sprint 4 - ข้อ 5 : Admin users & reports  (Widget tests)
//
// หัวข้อที่ได้รับ: Manage users, adjust credit, problem reports, feedback
//   ไฟล์ที่ทดสอบ: lib/admin/users_screen.dart  และ  lib/admin/reports_screen.dart
//   (รวมแผ่นรายละเอียด lib/admin/sheets.dart ที่เปิดจากหน้าทั้งสอง)
//
// วิธีรัน (ต้องอยู่ในโฟลเดอร์ frontend/ecoride_app):
//   flutter test test/admin_users_reports_test.dart --reporter expanded     ← ทั้งไฟล์
//   flutter test test/admin_users_reports_test.dart --plain-name "UsersTab"   ← เฉพาะกลุ่ม Users
//   flutter test test/admin_users_reports_test.dart --plain-name "ReportsTab" ← เฉพาะกลุ่ม Reports
//   flutter test test/admin_users_reports_test.dart --plain-name "ปรับเครดิต"   ← เฉพาะเทสต์ที่ชื่อมีคำนี้
//
// หลักการ: ไม่ต่อ server จริง ใช้ fake_backend.dart (MockClient) ตอบ JSON แทน
//   แอปเรียก API ผ่าน AppStore -> ApiClient -> MockClient -> ตารางเส้นทาง b.routes
//   เทสต์จึงตรวจได้ทั้ง "หน้าจอแสดงผลถูก" และ "ปุ่มที่กดส่ง request ถูก path/body"
// =============================================================================
import 'dart:convert';

import 'package:ecoride_app/admin/reports_screen.dart';
import 'package:ecoride_app/admin/users_screen.dart';
import 'package:ecoride_app/core/ui.dart' show baht; // baht(150) = '฿150', baht(-100) = '−฿100'
import 'package:ecoride_app/widgets/basic.dart' show Kpi; // การ์ดตัวเลข (Credit / Rides total)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_backend.dart'; // signIn, pumpApp, adminBackend, FakeBackend, FakeErr, userJson, rideJson ...

// ขนาดจอจำลอง: กว้างพอให้ข้อความไม่ล้นแถว (ในเทสต์ฟอนต์ Ahem กว้างเท่าขนาดตัวอักษร)
const _screen = Size(900, 1600);

// =============================================================================
//  ตัวช่วยทั่วไป (helpers)
// =============================================================================

/// แปลง body ของ request ที่แอปส่งมา (String JSON) กลับเป็น Map ให้ route ของ backend ปลอมอ่านค่า
Map<String, dynamic> _json(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;

/// รอให้งาน async ของแอป (เรียก API ปลอม -> refresh -> notifyListeners) และแอนิเมชันเสร็จ
///  - runAsync = ให้ event loop จริงทำงาน 5 ms (เผื่อ future ที่ไม่ใช่ microtask)
///  - pump(120ms) = ให้ Flutter วาดหน้าใหม่ + เดินแอนิเมชัน (dialog/sheet/snackbar) ไปทีละนิด
///  ทำ 4 รอบ รวม ~0.5 วินาที พอสำหรับทุกปุ่มในไฟล์นี้
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// กดวิดเจ็ตที่ finder ชี้ แล้วรอให้ผลเสร็จ
///  ensureVisible = เลื่อนรายการให้วิดเจ็ตอยู่ในจอก่อนกด (กันกรณีปุ่มอยู่ล่างสุดของ ListView)
Future<void> tapOn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

/// กดวิดเจ็ตจากข้อความ (ข้อความต้องตรงทั้งหมด และต้องเจอแค่ 1 ที่)
Future<void> tapText(WidgetTester tester, String text) => tapOn(tester, find.text(text));

/// ช่องกรอกที่อยู่ใน dialog (ไม่นับช่องค้นหาที่อยู่หน้าหลัก)  .at(0) = ช่องแรก, .at(1) = ช่องที่สอง
Finder dialogFields() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

/// ล็อกอินเป็นแอดมินกับ backend ปลอม แล้ววาดหน้าที่จะทดสอบ
///  signIn = สร้าง AppStore ที่ต่อ backend ปลอม + ล็อกอิน + โหลดข้อมูลทั้งระบบ
///  pumpApp = วาดวิดเจ็ตใน MaterialApp (หน้า Users/Reports ต้องมี Scaffold ครอบ จึงใส่ให้)
Future<void> openScreen(WidgetTester tester, FakeBackend b, Widget screen) async {
  await signIn(tester, b, username: 'admin');
  await pumpApp(tester, Scaffold(body: screen), size: _screen);
  await settle(tester);
}

/// เปิดหน้า Users แล้วกดชื่อนักศึกษาเพื่อเข้าหน้ารายละเอียด (UserDetailScreen)
Future<FakeBackend> openUserDetail(WidgetTester tester,
    {FakeBackend? backend, String name = 'Somchai Jaidee'}) async {
  final b = backend ?? usersBackend();
  await openScreen(tester, b, const UsersTab());
  await tapText(tester, name);
  expect(find.byType(UserDetailScreen), findsOneWidget);
  return b;
}

/// เปิดหน้า Reports (initial: 0=Issues 1=Rides 2=Top-ups 3=Feedback)
Future<FakeBackend> openReports(WidgetTester tester, {FakeBackend? backend, int initial = 0}) async {
  final b = backend ?? reportsBackend();
  await openScreen(tester, b, ReportsTab(initial: initial));
  return b;
}

/// ตัวเลขเครดิตในการ์ด Kpi "Credit" ของหน้ารายละเอียดผู้ใช้ เช่น creditKpi('฿150')
Finder creditKpi(String value) =>
    find.descendant(of: find.widgetWithText(Kpi, 'Credit'), matching: find.text(value));

/// จำกัดการค้นหาให้อยู่ "ในหน้ารายละเอียดผู้ใช้" เท่านั้น
/// เหตุผล: ตอนเปิดหน้ารายละเอียด หน้ารายชื่อด้านล่างยังอยู่ใน widget tree ของ Flutter
/// ข้อความเดียวกัน (เช่น รหัส · username, ป้าย Disabled) จึงโผล่ซ้ำ 2 ที่ ถ้าไม่จำกัดขอบเขต
Finder inDetail(Finder f) => find.descendant(of: find.byType(UserDetailScreen), matching: f);

// =============================================================================
//  backend ปลอมสำหรับเทสต์นี้
//  adminBackend() ของเพื่อนตอบได้แค่ "อ่านข้อมูล" (GET)
//  ที่นี่เพิ่ม route ฝั่ง "เขียนข้อมูล" (POST/PUT) และให้ GET ตัวถัดไปคืนค่าที่เปลี่ยนแล้ว
//  เหมือน server จริง -> หน้าจอหลัง refresh() จึงเห็นค่าใหม่
// =============================================================================

/// backend สำหรับหน้า Users: somchai.j (id 1, เครดิต 150) และ malee.r (id 3, เครดิต 40)
FakeBackend usersBackend({bool somchaiActive = true}) {
  final b = adminBackend();
  final users = <Map<String, Object?>>[
    userJson(1, 'somchai.j', active: somchaiActive),
    userJson(3, 'malee.r', credit: 40),
  ];

  // อ่านรายชื่อ: คืน list ตัวเดียวกันเสมอ (route อื่นแก้ค่าใน list นี้)
  b.routes['GET /api/admin/users'] = (_) => users;

  // ปรับเครดิต: body = {amount, reason, refund}
  //  amount เป็น 0 -> error / หักจนติดลบ -> error (จำลองกฎของ backend) / ปกติ -> เปลี่ยนยอด
  b.routes['POST /api/admin/users/1/credit'] = (r) {
    final amount = (_json(r)['amount'] as num).toDouble();
    final current = (users[0]['credit_balance'] as num).toDouble();
    if (amount == 0) return FakeErr(400, 'Amount must not be zero');
    if (current + amount < 0) return FakeErr(400, 'Insufficient credit');
    users[0]['credit_balance'] = current + amount;
    return {'ok': true};
  };

  // แก้ชื่อ + รหัสนักศึกษา: body = {full_name, student_id}
  b.routes['PUT /api/admin/users/1'] = (r) {
    users[0]['full_name'] = _json(r)['full_name'];
    users[0]['student_id'] = _json(r)['student_id'];
    return {'ok': true};
  };

  // ระงับ/เปิดบัญชี: body = {active: true/false}
  b.routes['PUT /api/admin/users/1/active'] = (r) {
    users[0]['is_active'] = _json(r)['active'] == true ? 1 : 0;
    return {'ok': true};
  };
  return b;
}

/// รายงานปัญหา 1 รายการ (รูปแบบเดียวกับ GET /api/admin/reports)
Map<String, Object?> _report(int id,
        {required int vehicleId,
        required int userId,
        required String category,
        required String details,
        String status = 'open',
        int? rideId}) =>
    {
      'report_id': id,
      'user_id': userId,
      'vehicle_id': vehicleId,
      'ride_id': rideId,
      'category': category,
      'is_urgent': details.startsWith('[URGENT]'), // แอปดูจาก details ขึ้นต้นด้วย [URGENT]
      'details': details,
      'status': status,
      'created_at': DateTime.now().subtract(Duration(minutes: id * 10)).toIso8601String(),
      'resolved_at': status == 'resolved' ? DateTime.now().toIso8601String() : null,
    };

/// backend สำหรับหน้า Reports: มี issue 3 รายการ, ride 3 รายการ, top-up 2 รายการ, feedback 2 รายการ
FakeBackend reportsBackend() {
  final b = adminBackend();
  final now = DateTime.now();
  String t(Duration ago) => now.subtract(ago).toIso8601String(); // เวลาย้อนหลังจากตอนนี้

  // ---- Issues: #2 ด่วน(เปิด) · #3 ธรรมดา(เปิด) · #4 แก้แล้ว  (คนละรถ คนละผู้ใช้)
  final reports = <Map<String, Object?>>[
    _report(2,
        vehicleId: 1,
        userId: 1,
        rideId: 7,
        category: 'accident',
        details: '[URGENT] Accident · at: gate 2'),
    _report(3, vehicleId: 2, userId: 3, category: 'brakes_wheels', details: 'Brake is loose'),
    _report(4,
        vehicleId: 5,
        userId: 1,
        category: 'low_battery',
        details: 'Battery drains fast',
        status: 'resolved'),
  ];
  b.routes['GET /api/admin/reports'] = (_) => reports;
  // เปลี่ยนสถานะ issue: body = {status: open | in_progress | resolved}
  for (final id in [2, 3, 4]) {
    b.routes['PUT /api/admin/reports/$id/status'] = (r) {
      final status = _json(r)['status'] as String;
      final rep = reports.firstWhere((x) => x['report_id'] == id);
      rep['status'] = status;
      rep['resolved_at'] = status == 'resolved' ? DateTime.now().toIso8601String() : null;
      return {'ok': true};
    };
  }
  // ส่งรถซ่อม: body = {repair: true/false}
  b.routes['PUT /api/admin/vehicles/1/maintenance'] = (_) => {'ok': true};
  b.routes['PUT /api/admin/vehicles/2/maintenance'] = (_) => {'ok': true};

  // ---- Rides: เวลากำหนดจาก "ตอนนี้" เพื่อให้ผล overdue/riding ไม่เปลี่ยนตามวันที่รันเทสต์
  b.routes['GET /api/admin/rides'] = (_) => [
        // ride 7: somchai ยืม EB-012 เกินกำหนดมา 6 ชม.  -> Overdue
        {...rideJson(id: 7), 'start_time': t(const Duration(hours: 30)), 'due_time': t(const Duration(hours: 6))},
        // ride 8: malee ยืม EB-015 ยังไม่ถึงกำหนด  -> Riding
        {
          ...rideJson(id: 8, vehicleId: 2, userId: 3),
          'start_time': t(const Duration(hours: 1)),
          'due_time': now.add(const Duration(hours: 23)).toIso8601String(),
        },
        // ride 6: somchai คืน EB-021 แล้ว  -> Returned (ไม่อยู่ในแท็บ Out now)
        {
          ...rideJson(id: 6, status: 'returned', vehicleId: 5),
          'start_time': t(const Duration(hours: 50)),
          'due_time': t(const Duration(hours: 26)),
          'end_time': t(const Duration(hours: 49)),
        },
      ];

  // ---- Top-ups: #5 รอยืนยัน (malee, ฿200) · #4 จ่ายแล้ว (somchai, ฿100)
  final pending = <String, Object?>{
    ...topupJson(5, userId: 3),
    'reference_code': 'ECO3-X',
    'created_at': t(const Duration(minutes: 20)),
  };
  final paid = <String, Object?>{
    ...topupJson(4, userId: 1, amount: 100, status: 'paid'),
    'created_at': t(const Duration(hours: 3)),
    'paid_at': t(const Duration(hours: 3)),
  };
  b.routes['GET /api/admin/topups'] = (_) => [pending, paid];
  b.routes['POST /api/admin/topups/5/confirm'] = (_) {
    pending['status'] = 'paid';
    pending['paid_at'] = DateTime.now().toIso8601String();
    return {'topup': pending}; // แอปอ่านผลจาก res['topup']
  };
  b.routes['POST /api/admin/topups/5/reject'] = (_) {
    pending['status'] = 'failed';
    return {'ok': true};
  };

  // ---- Feedback: #1 ใหม่ (malee, payment) · #2 แก้แล้ว (somchai, suggestion)
  final feedback = <Map<String, Object?>>[
    {
      'feedback_id': 1,
      'user_id': 3,
      'topic': 'payment',
      'message': 'Credit was slow',
      'status': 'open',
      'created_at': t(const Duration(hours: 2)),
    },
    {
      'feedback_id': 2,
      'user_id': 1,
      'topic': 'suggestion',
      'message': 'Add dark mode',
      'status': 'resolved',
      'created_at': t(const Duration(hours: 5)),
    },
  ];
  b.routes['GET /api/admin/feedback'] = (_) => feedback;
  for (final id in [1, 2]) {
    b.routes['PUT /api/admin/feedback/$id/status'] = (r) {
      feedback.firstWhere((x) => x['feedback_id'] == id)['status'] = _json(r)['status'];
      return {'ok': true};
    };
  }
  return b;
}

// =============================================================================
//  เทสต์
// =============================================================================
void main() {
  // ===========================================================================
  //  กลุ่ม 1: UsersTab  (Manage users + Adjust credit)
  // ===========================================================================
  group('UsersTab', () {
    // ---------------------------------------------------------------- รายชื่อ
    testWidgets('แสดงรายชื่อนักศึกษา จำนวน เครดิต และสถานะ Riding', (tester) async {
      await openScreen(tester, usersBackend(), const UsersTab());

      expect(find.byType(UsersTab), findsOneWidget);
      expect(find.text('Users'), findsOneWidget); // หัวข้อ
      expect(find.text('2 students'), findsOneWidget); // นับเฉพาะนักศึกษา
      expect(find.text('Somchai Jaidee'), findsOneWidget);
      expect(find.text('Malee Ratanachai'), findsOneWidget);
      expect(find.text('6731501118 · somchai.j'), findsOneWidget); // รหัส · username
      expect(find.text('6731502229 · malee.r'), findsOneWidget);
      expect(find.text('SJ'), findsOneWidget); // อักษรย่อใน avatar
      expect(find.text(baht(150)), findsOneWidget); // เครดิตของ somchai
      expect(find.text(baht(40)), findsOneWidget); // เครดิตของ malee
      expect(find.text('EcoRide Admin'), findsNothing); // แอดมินไม่ถูกนับเป็นนักศึกษา
      expect(find.text('Riding'), findsOneWidget); // somchai มี ride ที่ยังไม่คืน
    });

    testWidgets('บัญชีที่ถูกระงับแสดงป้าย Disabled (แทน Riding)', (tester) async {
      await openScreen(tester, usersBackend(somchaiActive: false), const UsersTab());

      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Riding'), findsNothing);
    });

    // ----------------------------------------------------------------- ค้นหา
    testWidgets('ช่องค้นหา: กรองตามชื่อ, รหัสนักศึกษา, username (ไม่สนตัวพิมพ์ใหญ่เล็ก/ช่องว่างหัวท้าย)',
        (tester) async {
      await openScreen(tester, usersBackend(), const UsersTab());
      final search = find.byType(TextField); // หน้านี้มีช่องเดียวคือช่องค้นหา

      await tester.enterText(search, 'malee'); // ค้นด้วยชื่อ
      await tester.pump();
      expect(find.text('Somchai Jaidee'), findsNothing);
      expect(find.text('Malee Ratanachai'), findsOneWidget);

      await tester.enterText(search, '6731501118'); // ค้นด้วยรหัสนักศึกษา
      await tester.pump();
      expect(find.text('Somchai Jaidee'), findsOneWidget);
      expect(find.text('Malee Ratanachai'), findsNothing);

      await tester.enterText(search, 'SOMCHAI.J'); // พิมพ์ใหญ่ + username
      await tester.pump();
      expect(find.text('Somchai Jaidee'), findsOneWidget);
      expect(find.text('Malee Ratanachai'), findsNothing);

      await tester.enterText(search, '   malee   '); // เว้นวรรคหัวท้ายถูกตัด (trim)
      await tester.pump();
      expect(find.text('Malee Ratanachai'), findsOneWidget);

      await tester.enterText(search, 'zzz'); // ไม่เจอใคร
      await tester.pump();
      expect(find.text('No users found'), findsOneWidget);
      expect(find.text('2 students'), findsOneWidget); // จำนวนรวมยังเท่าเดิม

      await tester.enterText(search, ''); // ล้างคำค้น -> กลับมาครบ
      await tester.pump();
      expect(find.text('Somchai Jaidee'), findsOneWidget);
      expect(find.text('Malee Ratanachai'), findsOneWidget);
    });

    // ------------------------------------------------------------- รายละเอียด
    testWidgets('กดชื่อ -> เปิดหน้ารายละเอียด: เครดิต, จำนวนการยืม, ประวัติยืม, ประวัติเครดิต', (tester) async {
      await openUserDetail(tester); // somchai

      expect(inDetail(find.text('User')), findsOneWidget); // ชื่อหน้า
      expect(inDetail(find.text('Active')), findsOneWidget);
      expect(inDetail(find.text('6731501118 · somchai.j')), findsOneWidget);
      expect(creditKpi(baht(150)), findsOneWidget); // การ์ด Credit = ฿150
      expect(
        find.descendant(of: find.widgetWithText(Kpi, 'Rides total'), matching: find.text('1')),
        findsOneWidget, // ยืมมา 1 ครั้ง
      );
      expect(inDetail(find.text('Adjust credit')), findsOneWidget);
      expect(inDetail(find.text('Disable account')), findsOneWidget);
      expect(inDetail(find.text('Rides')), findsOneWidget); // หัวข้อประวัติยืม
      expect(inDetail(find.textContaining('EB-012')), findsWidgets); // ride ของรถ EB-012
      expect(inDetail(find.text('Credit history')), findsOneWidget);
      expect(inDetail(find.text(baht(-100))), findsOneWidget); // รายการหักเงินค่ายืม
      expect(inDetail(find.text('Bal. ${baht(50)}')), findsOneWidget); // ยอดคงเหลือหลังรายการ
    });

    testWidgets('ผู้ใช้ที่ยังไม่เคยยืม/ไม่มีธุรกรรม แสดงข้อความว่าง', (tester) async {
      await openUserDetail(tester, name: 'Malee Ratanachai');

      expect(creditKpi(baht(40)), findsOneWidget);
      expect(find.text('No rides yet'), findsOneWidget);
      expect(find.text('No transactions'), findsOneWidget);
    });

    // ------------------------------------------------------------- แก้ข้อมูล
    testWidgets('แก้ไขข้อมูล: dialog มีค่าเดิม, Save ส่ง PUT แล้วหน้าจอเปลี่ยนตาม', (tester) async {
      final b = await openUserDetail(tester);

      await tapOn(tester, find.byTooltip('Edit details')); // ปุ่มดินสอ
      expect(find.text('Edit user'), findsOneWidget);
      expect(find.text('Username cannot be changed (used to log in).'), findsOneWidget);
      // ช่องกรอกมีค่าเดิมใส่ไว้ให้
      expect(tester.widget<TextField>(dialogFields().at(0)).controller!.text, 'Somchai Jaidee');
      expect(tester.widget<TextField>(dialogFields().at(1)).controller!.text, '6731501118');

      await tester.enterText(dialogFields().at(0), 'Somchai New');
      await tester.enterText(dialogFields().at(1), '6731509999');
      await tester.pump();
      await tapText(tester, 'Save');

      // 1) แอปส่ง request ถูกต้อง
      final body = b.lastBody('PUT', '/api/admin/users/1');
      expect(body, isNotNull, reason: 'กด Save แล้วต้องเรียก PUT /api/admin/users/1');
      expect(body!['full_name'], 'Somchai New');
      expect(body['student_id'], '6731509999');
      // 2) หน้าจอตอบสนอง
      expect(find.text('Edit user'), findsNothing); // dialog ปิด
      expect(find.text('User updated'), findsOneWidget); // toast สำเร็จ
      expect(find.text('Somchai New'), findsWidgets); // ชื่อใหม่ขึ้นในหน้ารายละเอียด
      expect(find.text('Somchai Jaidee'), findsNothing);
      expect(find.text('6731509999 · somchai.j'), findsOneWidget); // รหัสใหม่ + username เดิม
    });

    testWidgets('แก้ไขข้อมูล: กด Cancel ต้องไม่ส่ง request และข้อมูลเดิมไม่เปลี่ยน', (tester) async {
      final b = await openUserDetail(tester);

      await tapOn(tester, find.byTooltip('Edit details'));
      await tester.enterText(dialogFields().at(0), 'Should Not Save');
      await tester.pump();
      await tapText(tester, 'Cancel');

      expect(find.text('Edit user'), findsNothing);
      expect(b.lastCall('PUT', '/api/admin/users/1'), isNull);
      expect(find.text('Somchai Jaidee'), findsWidgets);
    });

    testWidgets('แก้ไขข้อมูล (กรณี error): backend ปฏิเสธ -> toast แดง + dialog ยังเปิดอยู่', (tester) async {
      final b = usersBackend();
      b.routes['PUT /api/admin/users/1'] = (_) => FakeErr(409, 'Student ID already in use');
      await openUserDetail(tester, backend: b);

      await tapOn(tester, find.byTooltip('Edit details'));
      await tester.enterText(dialogFields().at(1), '6731502229'); // ซ้ำกับ malee
      await tester.pump();
      await tapText(tester, 'Save');

      expect(find.text('Student ID already in use'), findsOneWidget); // ข้อความจาก backend ขึ้น toast
      expect(find.text('Edit user'), findsOneWidget); // dialog ไม่ปิด ให้แก้ต่อได้
      expect(find.text('User updated'), findsNothing);
    });

    // ----------------------------------------------------------- ปรับเครดิต
    testWidgets('ปรับเครดิต: dialog แสดงยอดปัจจุบัน ตัวเลือก เพิ่ม/หัก และช่อง refund', (tester) async {
      await openUserDetail(tester);

      await tapText(tester, 'Adjust credit');
      expect(find.text('Adjust credit · Somchai'), findsOneWidget); // ชื่อแรกของผู้ใช้
      expect(find.text('Current: ${baht(150)}'), findsOneWidget);
      expect(find.textContaining('Add'), findsWidgets);
      expect(find.textContaining('Deduct'), findsOneWidget);
      expect(find.text('This is a refund'), findsOneWidget); // โหมดเพิ่ม: มีช่อง refund
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('ปรับเครดิต: เพิ่ม ฿50 -> ส่ง POST ถูกต้อง, เครดิตเป็น ฿200, toast สำเร็จ', (tester) async {
      final b = await openUserDetail(tester);

      await tapText(tester, 'Adjust credit');
      await tester.enterText(dialogFields().at(0), '50'); // จำนวนเงิน
      await tester.enterText(dialogFields().at(1), 'Bonus'); // เหตุผล
      await tester.pump();
      await tapText(tester, 'Save');

      final body = b.lastBody('POST', '/api/admin/users/1/credit');
      expect(body, isNotNull);
      expect(body!['amount'], 50); // เพิ่ม = บวก
      expect(body['reason'], 'Bonus');
      expect(body['refund'], false); // ไม่ได้ติ๊ก refund
      expect(find.text('Current: ${baht(150)}'), findsNothing); // dialog ปิดแล้ว
      expect(find.text('Credit updated: ${baht(200)}'), findsOneWidget);
      expect(creditKpi(baht(200)), findsOneWidget); // การ์ด Credit อัปเดตหลัง refresh
    });

    testWidgets('ปรับเครดิต: ติ๊ก "This is a refund" -> body.refund = true', (tester) async {
      final b = await openUserDetail(tester);

      await tapText(tester, 'Adjust credit');
      await tester.enterText(dialogFields().at(0), '50');
      await tester.enterText(dialogFields().at(1), 'Refund - vehicle broke down');
      await tester.tap(find.byType(Checkbox)); // ติ๊ก refund
      await tester.pump();
      await tapText(tester, 'Save');

      final body = b.lastBody('POST', '/api/admin/users/1/credit');
      expect(body!['amount'], 50);
      expect(body['refund'], true);
      expect(body['reason'], 'Refund - vehicle broke down');
    });

    testWidgets('ปรับเครดิต: หัก ฿30 -> amount ติดลบ, refund เป็น false เสมอ (แม้เคยติ๊กไว้)', (tester) async {
      final b = await openUserDetail(tester);

      await tapText(tester, 'Adjust credit');
      await tester.tap(find.byType(Checkbox)); // ติ๊ก refund ก่อน
      await tester.pump();
      await tester.tap(find.textContaining('Deduct')); // แล้วสลับเป็นโหมดหัก
      await tester.pump();
      expect(find.text('This is a refund'), findsNothing); // โหมดหักไม่มีช่อง refund

      await tester.enterText(dialogFields().at(0), '30');
      await tester.enterText(dialogFields().at(1), 'Penalty');
      await tester.pump();
      await tapText(tester, 'Save');

      final body = b.lastBody('POST', '/api/admin/users/1/credit');
      expect(body!['amount'], -30);
      expect(body['refund'], false);
      expect(find.text('Credit updated: ${baht(120)}'), findsOneWidget);
      expect(creditKpi(baht(120)), findsOneWidget);
    });

    testWidgets('ปรับเครดิต: ช่องจำนวนเงินรับเฉพาะตัวเลข ไม่เกิน 4 หลัก', (tester) async {
      await openUserDetail(tester);

      await tapText(tester, 'Adjust credit');
      await tester.enterText(dialogFields().at(0), '12ab3456'); // มีตัวอักษร + ยาวเกิน
      await tester.pump();

      // ตัวอักษรถูกกรองทิ้ง เหลือ 123456 แล้วตัดเหลือ 4 หลัก
      expect(tester.widget<TextField>(dialogFields().at(0)).controller!.text, '1234');
    });

    testWidgets('ปรับเครดิต (กรณี error): หักเกินยอด -> toast แดง, dialog ค้าง, เครดิตไม่เปลี่ยน', (tester) async {
      final b = await openUserDetail(tester);

      await tapText(tester, 'Adjust credit');
      await tester.tap(find.textContaining('Deduct'));
      await tester.pump();
      await tester.enterText(dialogFields().at(0), '999'); // มี 150 หัก 999
      await tester.enterText(dialogFields().at(1), 'Too much');
      await tester.pump();
      await tapText(tester, 'Save');

      expect(b.lastCall('POST', '/api/admin/users/1/credit'), isNotNull); // แอปส่งไปแล้ว
      expect(find.text('Insufficient credit'), findsOneWidget); // ข้อความ error จาก backend
      expect(find.text('Current: ${baht(150)}'), findsOneWidget); // dialog ยังเปิดอยู่
      expect(creditKpi(baht(150)), findsOneWidget); // ยอดเดิม
    });

    testWidgets('ปรับเครดิต (กรณี error): ไม่กรอกจำนวน -> แอปส่ง 0 และ backend ปฏิเสธ', (tester) async {
      final b = await openUserDetail(tester);

      await tapText(tester, 'Adjust credit');
      await tapText(tester, 'Save'); // ไม่กรอกอะไรเลย

      // หมายเหตุ: แอปไม่ตรวจช่องว่างเอง (แปลงเป็น 0 แล้วส่ง) ให้ backend เป็นคนปฏิเสธ
      expect(b.lastBody('POST', '/api/admin/users/1/credit')!['amount'], 0);
      expect(find.text('Amount must not be zero'), findsOneWidget);
      expect(find.text('Current: ${baht(150)}'), findsOneWidget);
    });

    testWidgets('ปรับเครดิต: กด Cancel ต้องไม่ส่ง request', (tester) async {
      final b = await openUserDetail(tester);

      await tapText(tester, 'Adjust credit');
      await tester.enterText(dialogFields().at(0), '77');
      await tester.pump();
      await tapText(tester, 'Cancel');

      expect(find.text('Current: ${baht(150)}'), findsNothing);
      expect(b.lastCall('POST', '/api/admin/users/1/credit'), isNull);
      expect(creditKpi(baht(150)), findsOneWidget);
    });

    // ----------------------------------------------------- ระงับ / เปิดบัญชี
    testWidgets('ระงับบัญชี: ยืนยัน -> PUT active=false, ป้ายเป็น Disabled, ปุ่มเป็น Enable account', (tester) async {
      final b = await openUserDetail(tester);

      await tapText(tester, 'Disable account');
      expect(find.text('Disable Somchai?'), findsOneWidget); // กล่องยืนยันก่อนทำจริง
      expect(find.text('They will not be able to log in or borrow.'), findsOneWidget);
      await tapText(tester, 'Disable'); // ปุ่มยืนยันใน dialog

      expect(b.lastBody('PUT', '/api/admin/users/1/active')!['active'], false);
      expect(inDetail(find.text('Disabled')), findsOneWidget);
      expect(inDetail(find.text('Active')), findsNothing);
      expect(inDetail(find.text('Enable account')), findsOneWidget);
      expect(inDetail(find.text('Disable account')), findsNothing);
    });

    testWidgets('ระงับบัญชี: กด Cancel ในกล่องยืนยัน -> ไม่ส่ง request, ยัง Active', (tester) async {
      final b = await openUserDetail(tester);

      await tapText(tester, 'Disable account');
      await tapText(tester, 'Cancel');

      expect(b.lastCall('PUT', '/api/admin/users/1/active'), isNull);
      expect(inDetail(find.text('Active')), findsOneWidget);
      expect(inDetail(find.text('Disable account')), findsOneWidget);
    });

    testWidgets('เปิดบัญชีที่ถูกระงับ: ยืนยัน -> PUT active=true, กลับเป็น Active', (tester) async {
      final b = await openUserDetail(tester, backend: usersBackend(somchaiActive: false));

      expect(inDetail(find.text('Disabled')), findsOneWidget);
      await tapText(tester, 'Enable account');
      expect(find.text('Enable Somchai?'), findsOneWidget);
      expect(find.text('They can log in and borrow again.'), findsOneWidget);
      await tapText(tester, 'Enable');

      expect(b.lastBody('PUT', '/api/admin/users/1/active')!['active'], true);
      expect(inDetail(find.text('Active')), findsOneWidget);
      expect(inDetail(find.text('Disable account')), findsOneWidget);
    });
  });

  // ===========================================================================
  //  กลุ่ม 2: ReportsTab  (Problem reports + Feedback + Rides + Top-ups)
  // ===========================================================================
  group('ReportsTab', () {
    // ---------------------------------------------------------------- ภาพรวม
    testWidgets('แสดงหัวข้อและ 4 แท็บ พร้อมตัวเลขที่ค้างอยู่', (tester) async {
      await openReports(tester);

      expect(find.byType(ReportsTab), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Issues (2)'), findsOneWidget); // issue ที่ยังไม่ปิด 2 รายการ
      expect(find.text('Rides (1!)'), findsOneWidget); // ยืมเกินกำหนด 1 คัน
      expect(find.text('Top-ups (1)'), findsOneWidget); // รอยืนยัน 1 รายการ
      expect(find.text('Feedback (1)'), findsOneWidget); // ยังไม่อ่าน 1 รายการ
    });

    testWidgets('พารามิเตอร์ initial เปิดแท็บที่ต้องการตั้งแต่แรก (initial: 3 = Feedback)', (tester) async {
      await openReports(tester, initial: 3);

      expect(find.text('Payment / credit · Malee'), findsOneWidget);
      expect(find.text('Credit was slow'), findsOneWidget);
    });

    // ---------------------------------------------------------------- Issues
    testWidgets('Issues: แสดงรายการ เรียง ด่วน -> ยังไม่ปิด -> ปิดแล้ว พร้อมป้ายสถานะ', (tester) async {
      await openReports(tester);

      expect(find.textContaining('Need help?'), findsOneWidget); // คำอธิบายด้านบน
      expect(find.text('URGENT · Accident · EB-012'), findsOneWidget);
      expect(find.text('Brakes / wheels · EB-015'), findsOneWidget);
      expect(find.text('Low battery · EB-021'), findsOneWidget);
      expect(find.text('Open'), findsNWidgets(2)); // #2 และ #3
      expect(find.text('Resolved'), findsOneWidget); // #4

      double top(String text) => tester.getTopLeft(find.text(text)).dy; // ตำแหน่งแนวตั้ง
      expect(top('URGENT · Accident · EB-012'), lessThan(top('Brakes / wheels · EB-015')));
      expect(top('Brakes / wheels · EB-015'), lessThan(top('Low battery · EB-021')));
    });

    testWidgets('Issues: ไม่มีรายงาน -> แสดง No reports และแท็บไม่มีตัวเลข', (tester) async {
      final b = reportsBackend();
      b.routes['GET /api/admin/reports'] = (_) => <Object?>[];
      await openReports(tester, backend: b);

      expect(find.text('No reports'), findsOneWidget);
      expect(find.text('Issues'), findsOneWidget);
    });

    testWidgets('Issue ด่วน: กดแล้วเปิดแผ่นรายละเอียด มีข้อมูลผู้แจ้ง รถ ข้อความ และปุ่มจัดการ', (tester) async {
      await openReports(tester);

      await tapText(tester, 'URGENT · Accident · EB-012');
      expect(find.text('Need help · EB-012'), findsOneWidget); // หัวแผ่น
      expect(find.textContaining('Rider is waiting for staff'), findsOneWidget); // แบนเนอร์เตือน
      expect(find.text('Reported by'), findsOneWidget);
      expect(find.text('Student ID'), findsOneWidget);
      expect(find.text('6731501118'), findsOneWidget);
      expect(find.text('EB-012 · Electric bicycle'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget); // เลข ride ที่เกี่ยวข้อง
      expect(find.text('Accident · at: gate 2'), findsOneWidget); // ตัด "[URGENT] " ออกแล้ว
      expect(find.text('Accept · staff on the way'), findsOneWidget);
      expect(find.text('Mark as resolved'), findsOneWidget);
      expect(find.text('Send EB-012 to repair'), findsOneWidget);
      expect(find.text('Reopen'), findsNothing); // ยังไม่ปิด จึงไม่มีปุ่ม Reopen
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Issue ด่วน: กด Accept -> PUT status=in_progress, ป้ายเป็น In progress', (tester) async {
      final b = await openReports(tester);

      await tapText(tester, 'URGENT · Accident · EB-012');
      await tapText(tester, 'Accept · staff on the way');

      expect(b.lastBody('PUT', '/api/admin/reports/2/status')!['status'], 'in_progress');
      expect(find.text('In progress'), findsWidgets); // ทั้งในแผ่นและในรายการ
      expect(find.text('Accept · staff on the way'), findsNothing); // ปุ่มหายไป
      expect(find.text('Mark as resolved'), findsOneWidget); // ยังปิดงานได้
      expect(find.text('Issues (2)'), findsOneWidget); // in_progress ยังนับเป็นงานค้าง
    });

    testWidgets('Issue ด่วน: กด Mark as resolved -> PUT status=resolved, ขึ้น Reopen, ตัวเลขแท็บลด', (tester) async {
      final b = await openReports(tester);

      await tapText(tester, 'URGENT · Accident · EB-012');
      await tapText(tester, 'Mark as resolved');

      expect(b.lastBody('PUT', '/api/admin/reports/2/status')!['status'], 'resolved');
      expect(find.text('Reopen'), findsOneWidget);
      expect(find.text('Mark as resolved'), findsNothing);
      expect(find.text('Accept · staff on the way'), findsNothing);
      expect(find.text('Send EB-012 to repair'), findsNothing); // ปิดแล้วไม่ต้องส่งซ่อม
      expect(find.textContaining('Rider is waiting for staff'), findsNothing); // แบนเนอร์หาย
      expect(find.text('Issues (1)'), findsOneWidget); // เหลือค้าง 1
    });

    testWidgets('Issue: Reopen หลังปิดงาน -> PUT status=open, กลับมาเป็นงานค้าง', (tester) async {
      final b = await openReports(tester);

      await tapText(tester, 'URGENT · Accident · EB-012');
      await tapText(tester, 'Mark as resolved');
      await tapText(tester, 'Reopen');

      expect(b.lastBody('PUT', '/api/admin/reports/2/status')!['status'], 'open');
      expect(find.text('Accept · staff on the way'), findsOneWidget);
      expect(find.text('Reopen'), findsNothing);
      expect(find.text('Issues (2)'), findsOneWidget);
    });

    testWidgets('Issue ธรรมดา: หัวแผ่นเป็น Problem, ปุ่ม Start working on it ส่ง in_progress', (tester) async {
      final b = await openReports(tester);

      await tapText(tester, 'Brakes / wheels · EB-015');
      expect(find.text('Problem · EB-015'), findsOneWidget);
      expect(find.textContaining('Rider is waiting for staff'), findsNothing); // ไม่ใช่เคสด่วน
      expect(find.text('Brake is loose'), findsOneWidget); // รายละเอียดที่ผู้ใช้เขียน
      expect(find.text('Accept · staff on the way'), findsNothing);

      await tapText(tester, 'Start working on it');
      expect(b.lastBody('PUT', '/api/admin/reports/3/status')!['status'], 'in_progress');
      expect(find.text('Start working on it'), findsNothing);
    });

    testWidgets('Issue ที่ปิดแล้ว: มี Reopen แต่ไม่มีปุ่ม Resolve/Start/ส่งซ่อม', (tester) async {
      await openReports(tester);

      await tapText(tester, 'Low battery · EB-021');
      expect(find.text('Reopen'), findsOneWidget);
      expect(find.text('Mark as resolved'), findsNothing);
      expect(find.text('Start working on it'), findsNothing);
      expect(find.text('Send EB-021 to repair'), findsNothing);
    });

    testWidgets('ส่งรถซ่อมจาก issue: PUT repair=true และ toast ว่าย้ายไปซ่อมแล้ว', (tester) async {
      final b = await openReports(tester);

      await tapText(tester, 'URGENT · Accident · EB-012');
      await tapText(tester, 'Send EB-012 to repair');

      expect(b.lastBody('PUT', '/api/admin/vehicles/1/maintenance')!['repair'], true);
      expect(find.text('EB-012 moved to repair'), findsOneWidget);
    });

    testWidgets('ส่งรถซ่อม (กรณี error): backend ปฏิเสธ -> toast แสดงข้อความ error', (tester) async {
      final b = reportsBackend();
      b.routes['PUT /api/admin/vehicles/1/maintenance'] = (_) => FakeErr(409, 'Vehicle is in use');
      await openReports(tester, backend: b);

      await tapText(tester, 'URGENT · Accident · EB-012');
      await tapText(tester, 'Send EB-012 to repair');

      expect(find.text('Vehicle is in use'), findsOneWidget);
      expect(find.text('EB-012 moved to repair'), findsNothing);
    });

    testWidgets('เปลี่ยนสถานะ issue (กรณี error): toast แสดง error และสถานะไม่เปลี่ยน', (tester) async {
      final b = reportsBackend();
      b.routes['PUT /api/admin/reports/2/status'] = (_) => FakeErr(500, 'Server error');
      await openReports(tester, backend: b);

      await tapText(tester, 'URGENT · Accident · EB-012');
      await tapText(tester, 'Accept · staff on the way');

      expect(find.text('Server error'), findsOneWidget);
      expect(find.text('Accept · staff on the way'), findsOneWidget); // ปุ่มยังอยู่ = สถานะยัง open
      expect(find.text('Issues (2)'), findsOneWidget);
    });

    testWidgets('ปุ่ม Close ปิดแผ่นรายละเอียด', (tester) async {
      await openReports(tester);

      await tapText(tester, 'URGENT · Accident · EB-012');
      expect(find.text('Mark as resolved'), findsOneWidget);
      await tapText(tester, 'Close');

      expect(find.text('Mark as resolved'), findsNothing);
      expect(find.text('Need help · EB-012'), findsNothing);
    });

    // ----------------------------------------------------------------- Rides
    testWidgets('Rides: แท็บ Out now แสดงเฉพาะรถที่ยังไม่คืน พร้อมป้าย Overdue / Riding', (tester) async {
      await openReports(tester);

      await tapText(tester, 'Rides (1!)');
      expect(find.text('Out now'), findsOneWidget);
      expect(find.text('All rides'), findsOneWidget);
      expect(find.text('EB-012 · Somchai Jaidee'), findsOneWidget);
      expect(find.text('EB-015 · Malee Ratanachai'), findsOneWidget);
      expect(find.text('EB-021 · Somchai Jaidee'), findsNothing); // คืนแล้วไม่โชว์ใน Out now
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Riding'), findsOneWidget);
    });

    testWidgets('Rides: สลับเป็น All rides แล้วเห็นรายการที่คืนแล้วด้วย', (tester) async {
      await openReports(tester);

      await tapText(tester, 'Rides (1!)');
      await tapText(tester, 'All rides');

      expect(find.text('EB-021 · Somchai Jaidee'), findsOneWidget);
      expect(find.text('Returned'), findsOneWidget);
    });

    testWidgets('Rides: กดรายการ -> แผ่นรายละเอียด แจ้งเกินกำหนด สถานี และราคาที่จ่าย', (tester) async {
      await openReports(tester);

      await tapText(tester, 'Rides (1!)');
      await tapText(tester, 'EB-012 · Somchai Jaidee');

      expect(find.textContaining('Overdue by 6 h'), findsOneWidget); // เกินมา 6 ชม.
      expect(find.text('Station'), findsOneWidget);
      expect(find.text('Building 1'), findsWidgets);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text(baht(100)), findsWidgets);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Rides: ไม่มีรถที่ถูกยืมอยู่ -> No vehicles are out right now', (tester) async {
      final b = reportsBackend();
      b.routes['GET /api/admin/rides'] = (_) => <Object?>[];
      await openReports(tester, backend: b);

      await tapText(tester, 'Rides'); // ไม่มีเครื่องหมาย ! เพราะไม่มี overdue
      expect(find.text('No vehicles are out right now'), findsOneWidget);
    });

    // --------------------------------------------------------------- Top-ups
    testWidgets('Top-ups: แสดงสรุปยอด รายการรอยืนยัน และรายการที่จ่ายแล้ว', (tester) async {
      await openReports(tester);

      await tapText(tester, 'Top-ups (1)');
      expect(find.text('Topped up (month)'), findsOneWidget);
      expect(find.text('Ride revenue (month)'), findsOneWidget);
      expect(find.text('${baht(200)} · Malee Ratanachai'), findsOneWidget);
      expect(find.text('${baht(100)} · Somchai Jaidee'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget); // ป้ายของรายการที่รอยืนยัน
      expect(find.text('Paid'), findsOneWidget);
    });

    testWidgets('Top-ups: Confirm payment -> POST confirm, toast, ป้ายเป็น Paid, ตัวเลขแท็บหาย', (tester) async {
      final b = await openReports(tester);

      await tapText(tester, 'Top-ups (1)');
      await tapText(tester, '${baht(200)} · Malee Ratanachai');
      expect(find.text('${baht(200)} top-up'), findsOneWidget);
      expect(find.text('Check the payment arrived before confirming.'), findsOneWidget);
      expect(find.text('ECO3-X'), findsOneWidget); // reference code
      await tapText(tester, 'Confirm payment');

      expect(b.lastCall('POST', '/api/admin/topups/5/confirm'), isNotNull);
      expect(find.text('${baht(200)} added to Malee'), findsOneWidget);
      expect(find.text('Confirm payment'), findsNothing); // จ่ายแล้ว ปุ่มหาย
      expect(find.text('Mark as failed'), findsNothing);
      expect(find.text('Top-ups'), findsOneWidget); // ไม่มีรายการรอยืนยัน -> ไม่มีตัวเลข
    });

    testWidgets('Top-ups: Mark as failed -> POST reject, ป้ายเป็น failed', (tester) async {
      final b = await openReports(tester);

      await tapText(tester, 'Top-ups (1)');
      await tapText(tester, '${baht(200)} · Malee Ratanachai');
      await tapText(tester, 'Mark as failed');

      expect(b.lastCall('POST', '/api/admin/topups/5/reject'), isNotNull);
      expect(find.text('Failed'), findsOneWidget); // ป้ายหัวแผ่น
      expect(find.text('failed'), findsOneWidget); // ป้ายในรายการ
      expect(find.text('Confirm payment'), findsNothing);
    });

    // -------------------------------------------------------------- Feedback
    testWidgets('Feedback: แสดงรายการ หัวข้อ ผู้ส่ง ข้อความ และป้าย New/Resolved', (tester) async {
      await openReports(tester);

      await tapText(tester, 'Feedback (1)');
      expect(find.text('Payment / credit · Malee'), findsOneWidget);
      expect(find.text('Credit was slow'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Suggestion · Somchai'), findsOneWidget);
      expect(find.text('Add dark mode'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      // ที่ยังไม่แก้ไขอยู่เหนือที่แก้แล้ว
      expect(top('Payment / credit · Malee'), lessThan(top('Suggestion · Somchai')));
    });

    testWidgets('Feedback: เปิดอ่านแล้วถูกตั้งเป็น read อัตโนมัติ ตัวเลขแท็บหาย', (tester) async {
      final b = await openReports(tester);

      await tapText(tester, 'Feedback (1)');
      await tapText(tester, 'Payment / credit · Malee');

      expect(b.lastBody('PUT', '/api/admin/feedback/1/status')!['status'], 'read');
      expect(find.text('Payment / credit'), findsOneWidget); // หัวแผ่น
      expect(find.textContaining('Reply to malee.r'), findsOneWidget);
      expect(find.text('Credit was slow'), findsWidgets); // ในแผ่น + ในรายการ
      expect(find.text('Read'), findsWidgets);
      expect(find.text('Feedback (1)'), findsNothing); // ไม่มีที่ยังไม่อ่านแล้ว
      expect(find.text('Feedback'), findsOneWidget);
    });

    testWidgets('Feedback: Mark as resolved -> PUT status=resolved, ปุ่มหาย', (tester) async {
      final b = await openReports(tester);

      await tapText(tester, 'Feedback (1)');
      await tapText(tester, 'Payment / credit · Malee');
      await tapText(tester, 'Mark as resolved');

      expect(b.lastBody('PUT', '/api/admin/feedback/1/status')!['status'], 'resolved');
      expect(find.text('Mark as resolved'), findsNothing);
      expect(find.text('Resolved'), findsWidgets);
    });

    testWidgets('Feedback: ยังไม่มีความเห็น -> No feedback yet', (tester) async {
      final b = reportsBackend();
      b.routes['GET /api/admin/feedback'] = (_) => <Object?>[];
      await openReports(tester, backend: b, initial: 3);

      expect(find.text('No feedback yet'), findsOneWidget);
    });
  });
}
