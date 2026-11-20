import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoride_app/admin/admin_shell.dart';

import 'fake_backend.dart';

void main() {
  testWidgets('Overview shows admin header, KPIs, and attention items', (tester) async {
    await signIn(tester, adminBackend(), username: 'admin');
    await pumpApp(tester, const AdminShell());

    expect(find.text('EcoRide Admin'), findsOneWidget);
    expect(find.text('Riding now'), findsOneWidget);
    expect(find.text('Open issues'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('1 new feedback'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Old Gate'), 200);
    expect(find.text('Building 1'), findsWidgets);
    expect(find.text('Old Gate'), findsWidgets);
    expect(find.text('Closed'), findsWidgets);
  });

  testWidgets('Bottom nav switches across all 5 admin tabs', (tester) async {
    await signIn(tester, adminBackend(), username: 'admin');
    await pumpApp(tester, const AdminShell());

    await tester.tap(find.byKey(const Key('nav_1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Building 1'), findsWidgets);

    await tester.tap(find.byKey(const Key('nav_2')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('EB-012'), findsWidgets);

    await tester.tap(find.byKey(const Key('nav_3')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Everything riders do in the EcoRide app'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_4')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Search name, username or student ID'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_0')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('EcoRide Admin'), findsOneWidget);
  });

  testWidgets('Tapping Ready vehicles KPI opens Vehicles tab', (tester) async {
    await signIn(tester, adminBackend(), username: 'admin');
    await pumpApp(tester, const AdminShell());

    await tester.tap(find.text('Ready vehicles'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('EB-012'), findsWidgets);
  });

  testWidgets('Log out button opens confirmation dialog and cancels cleanly', (tester) async {
    await signIn(tester, adminBackend(), username: 'admin');
    await pumpApp(tester, const AdminShell());

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('You will need to log in again.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminShell), findsOneWidget);
  });
}