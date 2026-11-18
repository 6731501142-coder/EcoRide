// Example of using fake_backend.dart in widget tests (for #1-#5 to copy)
// Run with: flutter test test/fake_backend_usage_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoride_app/admin/admin_shell.dart';
import 'package:ecoride_app/widgets/basic.dart';

import 'fake_backend.dart';

void main() {
  // 1) widgets that don't call the backend -> just pumpApp
  testWidgets('Btn: tapping calls onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: Btn('Borrow', onTap: () => taps++)));
    await tester.tap(find.text('Borrow'));
    expect(taps, 1);
  });

  // 2) screens that use AppStore.instance -> signIn(...) first, then pumpApp
  testWidgets('AdminShell: opens with data from the fake backend', (tester) async {
    final s = await signIn(tester, adminBackend(), username: 'admin');
    expect(s.me!.isAdmin, isTrue);

    await pumpApp(tester, const AdminShell());
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);

    // switch to the Stations tab via the bottom bar (key: nav_1)
    await tester.tap(find.byKey(const Key('nav_1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Building 1'), findsWidgets);
  });
}
