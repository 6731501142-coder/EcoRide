// Sprint 4 - ข้อ 5: Admin users & reports (UsersTab, ReportsTab)
// รัน: flutter test test/admin_users_reports_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoride_app/admin/reports_screen.dart';
import 'package:ecoride_app/admin/users_screen.dart';

import 'fake_backend.dart';

void main() {
  testWidgets('UsersTab: แสดงรายชื่อนักศึกษาจาก backend', (tester) async {
    await signIn(tester, adminBackend(), username: 'admin');
    await pumpApp(tester, const Scaffold(body: UsersTab()));
    await tester.pumpAndSettle();

    expect(find.byType(UsersTab), findsOneWidget);
    expect(find.text('Somchai Jaidee'), findsWidgets);
    expect(find.text('Malee Ratanachai'), findsWidgets);
  });

  testWidgets('ReportsTab: เปิดหน้าได้และมีแท็บ Issues', (tester) async {
    await signIn(tester, adminBackend(), username: 'admin');
    await pumpApp(tester, const Scaffold(body: ReportsTab()));
    await tester.pumpAndSettle();

    expect(find.byType(ReportsTab), findsOneWidget);
    expect(find.textContaining('Issues'), findsWidgets);
  });
}
