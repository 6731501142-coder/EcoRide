// Sprint 4 - ข้อ 1: Auth & profile (auth_screens, account_screens, help_screen)
// รัน: flutter test test/auth_profile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:ecoride_app/data/app_store.dart';
import 'package:ecoride_app/data/avatars.dart';
import 'package:ecoride_app/data/models.dart';
import 'package:ecoride_app/screens/account_screens.dart';
import 'package:ecoride_app/screens/auth_screens.dart';
import 'package:ecoride_app/screens/help_screen.dart';
import 'package:ecoride_app/screens/home_shell.dart';

import 'fake_backend.dart';

void main() {
  const testSize = Size(800, 1000);

  // ------------------------------------------------------------------ 1. Login
  testWidgets('LoginScreen: กรอกรหัสผิดขึ้น error และล็อกอินถูกเข้าหน้า HomeShell',
      (tester) async {
    useFakeStore(studentBackend());
    await pumpApp(tester, const LoginScreen(), size: testSize);

    // ทดสอบกรอกรหัสผ่านผิด
    await tester.enterText(find.byKey(const Key('login_user')), 'somchai.j');
    await tester.enterText(find.byKey(const Key('login_pass')), 'wrongpass');
    await tester.tap(find.byKey(const Key('btn_login')));
    await tester.pumpAndSettle();

    expect(find.text('Wrong username or password'), findsOneWidget);
    expect(AppStore.instance.me, isNull);

    // ทดสอบล็อกอินถูกต้อง
    await tester.enterText(find.byKey(const Key('login_pass')), 'password123');
    await tester.tap(find.byKey(const Key('btn_login')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);

    // ล็อกเอาต์ปิดท้ายเพื่อหยุด Timer ของ AppStore ตามคู่มือใน fake_backend.dart
    AppStore.instance.logout();
  });

  // ------------------------------------------------------------------ 2. Sign up
  testWidgets('RegisterScreen: สมัครสมาชิกสำเร็จและส่งข้อมูลไปที่ backend',
      (tester) async {
    final b = studentBackend();
    useFakeStore(b);
    await pumpApp(tester, const RegisterScreen(), size: testSize);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Yaya Urassaya');
    await tester.enterText(fields.at(1), '6731509999');
    await tester.enterText(fields.at(2), 'yaya.u');
    await tester.enterText(fields.at(3), 'password123');
    await tester.enterText(fields.at(4), 'password123');

    await tester.tap(find.byKey(const Key('btn_signup')));
    await tester.pumpAndSettle();

    expect(b.lastBody('POST', '/api/auth/register'), containsPair('username', 'yaya.u'));
  });

  // ------------------------------------------------------------------ 3. Forgot username & Reset password
  testWidgets('ResetPasswordScreen: ค้นหา username และตั้งรหัสผ่านใหม่ได้',
      (tester) async {
    final b = studentBackend();
    useFakeStore(b);
    await pumpApp(tester, const ResetPasswordScreen(), size: testSize);

    // กดไปหน้า Forgot username
    await tester.tap(find.byKey(const Key('btn_forgot_username')));
    await tester.pumpAndSettle();

    final forgotFields = find.byType(TextField);
    await tester.enterText(forgotFields.at(0), '6731501118');
    await tester.enterText(forgotFields.at(1), 'Somchai Jaidee');
    await tester.tap(find.byKey(const Key('btn_find_username')));
    await tester.pumpAndSettle();

    expect(find.text('somchai.j'), findsOneWidget);

    // กดใช้ username ที่พบกลับมาหน้า Reset password
    await tester.tap(find.text('Use this username'));
    await tester.pumpAndSettle();

    final resetFields = find.byType(TextField);
    await tester.enterText(resetFields.at(1), '6731501118');
    await tester.enterText(resetFields.at(2), 'Somchai Jaidee');
    await tester.enterText(resetFields.at(3), 'newpass123');
    await tester.enterText(resetFields.at(4), 'newpass123');

    await tester.tap(find.byKey(const Key('btn_reset')));
    await tester.pumpAndSettle();

    expect(b.lastCall('POST', '/api/auth/reset-password'), isNotNull);
  });

  // ------------------------------------------------------------------ 4. Profile & รูปประจำตัว
  testWidgets('ProfileTab: แสดงข้อมูลโปรไฟล์และเปลี่ยนรูปประจำตัว (Avatar) ได้',
      (tester) async {
    final firstAvatar = presetAvatars.first;
    final b = studentBackend();
    Map<String, Object?> avatarReply(_) {
      final updated = {...userJson(1, 'somchai.j'), 'avatar_id': firstAvatar.id};
      return {...updated, 'user': updated};
    }

    b.routes['PUT /api/me/avatar'] = avatarReply;
    b.routes['POST /api/me/avatar'] = avatarReply;

    await signIn(tester, b);
    await pumpApp(tester, const Scaffold(body: ProfileTab()), size: testSize);
    await tester.pumpAndSettle();

    expect(find.text('Somchai Jaidee'), findsOneWidget);
    expect(find.text('6731501118 · Student'), findsOneWidget);

    // กดปุ่มกล้องเพื่อเลือกอวาตาร์สำเร็จรูป
    await tester.tap(find.byIcon(TablerIcons.camera));
    await tester.pumpAndSettle();

    expect(find.text('Choose an avatar'), findsOneWidget);
    await tester.tap(find.byKey(Key('avatar_${firstAvatar.id}')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(AppStore.instance.avatarId, firstAvatar.id);
  });

  // ------------------------------------------------------------------ 5. Edit profile & Change password
  testWidgets('AccountSettingsScreen: แสดงข้อมูลส่วนตัวที่ล็อกไว้และเปลี่ยนรหัสผ่านได้',
      (tester) async {
    final b = studentBackend();
    await signIn(tester, b);
    await pumpApp(tester, const AccountSettingsScreen(), size: testSize);
    await tester.pumpAndSettle();

    // ตรวจสอบข้อมูลส่วนตัวที่ผูกกับทะเบียนนักศึกษา
    expect(find.text('Account settings'), findsOneWidget);
    expect(find.text('Somchai Jaidee'), findsOneWidget);
    expect(find.text('6731501118'), findsOneWidget);
    expect(find.text('somchai.j'), findsOneWidget);

    // กรอกเปลี่ยนรหัสผ่าน
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'password123');
    await tester.enterText(fields.at(1), 'newpass123');
    await tester.enterText(fields.at(2), 'newpass123');

    await tester.tap(find.byKey(const Key('btn_save_account')));
    await tester.pumpAndSettle();

    expect(b.lastCall('PUT', '/api/me/password'), isNotNull);
  });

  // ------------------------------------------------------------------ 6. Help page
  testWidgets('HelpScreen: แสดงสายด่วนและส่งคำขอความช่วยเหลือฉุกเฉินได้',
      (tester) async {
    final b = studentBackend(withActiveRide: true)
      ..routes['POST /api/rides/7/help'] = (_) => {
            'report_id': 11,
            'user_id': 1,
            'vehicle_id': 1,
            'ride_id': 7,
            'category': 'brakes_wheels',
            'details': '[URGENT] Flat tyre · at: In front of Building 1',
            'status': 'open',
            'created_at': '2026-11-11 09:05:00',
            'resolved_at': null,
          };
    final s = await signIn(tester, b);
    await pumpApp(tester, HelpScreen(ride: s.activeRide!), size: testSize);
    await tester.pumpAndSettle();

    expect(find.text('Need help?'), findsOneWidget);
    expect(find.text('EcoRide staff hotline'), findsOneWidget);

    // เลือกประเภทปัญหาและกรอกตำแหน่ง
    await tester.tap(find.text(HelpType.flatTyre.label));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'In front of Building 1');

    // กดเรียกเจ้าหน้าที่และยืนยันใน Dialog
    await tester.tap(find.byKey(const Key('btn_call_staff')));
    await tester.pumpAndSettle();

    expect(find.text('Call staff now?'), findsOneWidget);
    await tester.tap(find.text('Call staff'));
    await tester.pumpAndSettle();

    expect(find.text('Staff have been notified'), findsOneWidget);
    expect(b.lastCall('POST', '/api/rides/7/help'), isNotNull);
  });
}