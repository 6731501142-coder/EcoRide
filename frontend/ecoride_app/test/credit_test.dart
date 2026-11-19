// Sprint 4 · #3 Credit and top-up → widget tests
// Screens: AddCreditScreen, PaymentHistoryScreen (screens/account_screens.dart)
//          + credit balance on ProfileTab (screens/home_shell.dart)
// Run only this file: flutter test test/credit_test.dart
//
// How AddCreditScreen works (so the tests make sense):
//   • 4 preset tiles ฿100 / ฿200 / ฿500 / ฿1,000 (฿200 picked by default) or type an amount in the TextField
//   • tap btn_topup → checks ฿20–฿5,000 in the app (toast error, no request sent)
//     → POST /api/topups → POST /api/topups/:id/confirm right away (no separate "I've paid" button)
//     → toast "฿200 added to your credit" → Navigator.pop()
//   • confirmTopup() reloads the balance from GET /api/me (not from the 'user' in the confirm reply),
//     so the fake backend below changes what GET /api/me returns after the confirm call.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoride_app/screens/account_screens.dart';
import 'package:ecoride_app/screens/home_shell.dart';

import 'fake_backend.dart';

// ---------------------------------------------------------------- helpers

/// let the tap run + wait for the fake API (create → confirm → refresh = several requests in a row)
/// and for the page transition / SnackBar animation
Future<void> _wait(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// student backend where top-up #3 works: POST /api/topups → pending, confirm → paid,
/// then GET /api/me (used by refresh) returns 150 + amount
FakeBackend _topupBackend() {
  num credit = 150;
  num lastAmount = 0;
  final b = studentBackend();
  b.routes['POST /api/topups'] = (req) {
    lastAmount = (jsonDecode(req.body) as Map<String, dynamic>)['amount'] as num;
    return topupJson(3, amount: lastAmount);
  };
  b.routes['POST /api/topups/3/confirm'] = (_) {
    credit = 150 + lastAmount;
    return {
      'topup': topupJson(3, amount: lastAmount, status: 'paid'),
      'user': userJson(1, 'somchai.j', credit: credit),
    };
  };
  b.routes['GET /api/me'] = (_) => userJson(1, 'somchai.j', credit: credit);
  return b;
}

/// AddCreditScreen calls Navigator.pop() after a successful top-up, so it must be pushed on top of another page
/// (if it were the only page, pop would leave nothing on screen). This opens it from a plain launcher page.
Future<void> _openAddCredit(WidgetTester tester) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddCreditScreen())),
            child: const Text('open add credit'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open add credit'));
  await _wait(tester);
  expect(find.byType(AddCreditScreen), findsOneWidget);
}

Future<void> _typeAmount(WidgetTester tester, String amount) async {
  await tester.enterText(find.byType(TextField), amount);
  await tester.pump();
}

Future<void> _tapTopup(WidgetTester tester) async {
  final btn = find.byKey(const Key('btn_topup'));
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await _wait(tester);
}

// ---------------------------------------------------------------- tests
void main() {
  group('AddCreditScreen', () {
    testWidgets('shows the current credit ฿150 and ฿200 is picked by default', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const AddCreditScreen());

      expect(find.text('Add credit'), findsOneWidget);
      expect(find.text('Current credit'), findsOneWidget);
      expect(find.text('฿150'), findsOneWidget);
      for (final tile in ['฿100', '฿200', '฿500', '฿1,000']) {
        expect(find.text(tile), findsOneWidget);
      }
      expect(find.text('Top up ฿200'), findsOneWidget);
    });

    testWidgets('top up 200 → sends {amount: 200}, confirms, credit becomes 350', (tester) async {
      final b = _topupBackend();
      final s = await signIn(tester, b);
      await _openAddCredit(tester);

      await _tapTopup(tester); // ฿200 is the default tile

      expect(b.lastBody('POST', '/api/topups'), {'amount': 200});
      expect(b.lastCall('POST', '/api/topups/3/confirm'), isNotNull);
      expect(s.me!.creditBalance, 350);
      expect(find.text('฿200 added to your credit'), findsOneWidget);
      expect(find.byType(AddCreditScreen), findsNothing); // screen closed after success
    });

    testWidgets('tap the ฿500 tile → button text changes and sends {amount: 500}', (tester) async {
      final b = _topupBackend();
      final s = await signIn(tester, b);
      await _openAddCredit(tester);

      await tester.tap(find.text('฿500'));
      await tester.pump();
      expect(find.text('Top up ฿500'), findsOneWidget);

      await _tapTopup(tester);

      expect(b.lastBody('POST', '/api/topups'), {'amount': 500});
      expect(s.me!.creditBalance, 650);
    });

    testWidgets('typed amount is used instead of the tile', (tester) async {
      final b = _topupBackend();
      await signIn(tester, b);
      await _openAddCredit(tester);

      await _typeAmount(tester, '350');
      expect(find.text('Top up ฿350'), findsOneWidget);

      await _tapTopup(tester);

      expect(b.lastBody('POST', '/api/topups'), {'amount': 350});
    });

    testWidgets('amount below ฿20 → error toast, no request sent', (tester) async {
      final b = _topupBackend();
      final s = await signIn(tester, b);
      await pumpApp(tester, const AddCreditScreen());

      await _typeAmount(tester, '10');
      await _tapTopup(tester);

      expect(find.text('Minimum top-up is ฿20'), findsOneWidget);
      expect(b.lastCall('POST', '/api/topups'), isNull);
      expect(s.me!.creditBalance, 150);
    });

    testWidgets('amount above ฿5,000 → error toast, no request sent', (tester) async {
      final b = _topupBackend();
      await signIn(tester, b);
      await pumpApp(tester, const AddCreditScreen());

      await _typeAmount(tester, '6000');
      await _tapTopup(tester);

      expect(find.text('Maximum top-up is ฿5,000 per time'), findsOneWidget);
      expect(b.lastCall('POST', '/api/topups'), isNull);
    });

    testWidgets('boundary ฿20 is allowed', (tester) async {
      final b = _topupBackend();
      final s = await signIn(tester, b);
      await _openAddCredit(tester);

      await _typeAmount(tester, '20');
      await _tapTopup(tester);

      expect(b.lastBody('POST', '/api/topups'), {'amount': 20});
      expect(s.me!.creditBalance, 170);
    });

    testWidgets('boundary ฿5,000 is allowed', (tester) async {
      final b = _topupBackend();
      final s = await signIn(tester, b);
      await _openAddCredit(tester);

      await _typeAmount(tester, '5000');
      await _tapTopup(tester);

      expect(b.lastBody('POST', '/api/topups'), {'amount': 5000});
      expect(s.me!.creditBalance, 5150);
    });

    testWidgets('amount field accepts digits only, max 4 digits', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const AddCreditScreen());

      String fieldText() => tester.widget<TextField>(find.byType(TextField)).controller!.text;

      await _typeAmount(tester, '12a34');
      expect(fieldText(), '1234'); // letters removed
      expect(find.text('Top up ฿1,234'), findsOneWidget);

      // clear first: when the field is already full (4 digits), Flutter keeps the old value
      await _typeAmount(tester, '');
      await _typeAmount(tester, '99999');
      expect(fieldText(), '9999'); // cut to 4 digits
    });

    testWidgets('backend rejects the top-up → shows its error, stays on the screen', (tester) async {
      final b = studentBackend()
        ..routes['POST /api/topups'] = (_) => FakeErr(400, 'Top-up must be between ฿20 and ฿5,000');
      final s = await signIn(tester, b);
      await pumpApp(tester, const AddCreditScreen());

      await _tapTopup(tester);

      expect(find.text('Top-up must be between ฿20 and ฿5,000'), findsOneWidget);
      expect(b.lastCall('POST', '/api/topups/3/confirm'), isNull); // never got a top-up to confirm
      expect(find.byType(AddCreditScreen), findsOneWidget);
      expect(s.me!.creditBalance, 150);
    });

    testWidgets('confirm is refused → shows the error, credit stays ฿150', (tester) async {
      final b = _topupBackend()
        ..routes['POST /api/topups/3/confirm'] = (_) => FakeErr(403, 'Only an admin can confirm this top-up');
      final s = await signIn(tester, b);
      await pumpApp(tester, const AddCreditScreen());

      await _tapTopup(tester);

      expect(b.lastBody('POST', '/api/topups'), {'amount': 200});
      expect(find.text('Only an admin can confirm this top-up'), findsOneWidget);
      expect(find.byType(AddCreditScreen), findsOneWidget);
      expect(s.me!.creditBalance, 150);
    });
  });

  group('PaymentHistoryScreen', () {
    testWidgets('shows the −฿100 ride payment as "Ride · EB-021"', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const PaymentHistoryScreen());

      expect(find.text('Payment history'), findsOneWidget);
      expect(find.text('Ride · EB-021'), findsOneWidget); // txnLabel(): ride 6 was on EB-021
      expect(find.text('−฿100'), findsOneWidget); // baht() uses the "−" minus sign
      expect(find.text('Bal. ฿150'), findsOneWidget);
      expect(find.text('No payments yet'), findsNothing);
    });

    testWidgets('top-up row shows +฿200 next to the ride payment', (tester) async {
      final b = studentBackend()
        ..routes['GET /api/credit/transactions'] = (_) => [
              txnJson(2,
                  type: 'topup',
                  amount: 200,
                  balanceAfter: 350,
                  topupId: 3,
                  note: 'Top up',
                  createdAt: '2026-11-11 10:00:05'),
              txnJson(1, amount: -100, balanceAfter: 150, rideId: 6),
            ];
      await signIn(tester, b);
      await pumpApp(tester, const PaymentHistoryScreen());

      expect(find.text('Top up'), findsOneWidget);
      expect(find.text('+฿200'), findsOneWidget);
      expect(find.text('Bal. ฿350'), findsOneWidget);
      expect(find.text('Ride · EB-021'), findsOneWidget);
    });

    testWidgets('no transactions → "No payments yet"', (tester) async {
      final b = studentBackend()..routes['GET /api/credit/transactions'] = (_) => [];
      await signIn(tester, b);
      await pumpApp(tester, const PaymentHistoryScreen());

      expect(find.text('No payments yet'), findsOneWidget);
      expect(find.text('Ride · EB-021'), findsNothing);
    });

    testWidgets('"Credit left" shows the balance ฿150', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const PaymentHistoryScreen());

      expect(find.text('Credit left'), findsOneWidget);
      expect(find.text('฿150'), findsOneWidget);
    });
  });

  group('Credit balance on Profile', () {
    testWidgets('Profile tab shows "Credit left" ฿150', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const HomeShell());

      await tester.tap(find.byKey(const Key('nav_2'))); // 0 Home · 1 History · 2 Profile
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Credit left'), findsOneWidget);
      expect(find.text('฿150'), findsOneWidget);
    });

    testWidgets('Profile → Add credit → top up ฿200 → Profile shows ฿350', (tester) async {
      final b = _topupBackend();
      await signIn(tester, b);
      await pumpApp(tester, const HomeShell());

      await tester.tap(find.byKey(const Key('nav_2')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Add credit'));
      await _wait(tester);
      expect(find.byType(AddCreditScreen), findsOneWidget);

      await _tapTopup(tester);

      expect(find.byType(AddCreditScreen), findsNothing); // popped back to Profile
      expect(find.text('฿350'), findsWidgets);
      expect(find.text('฿150'), findsNothing);
    });

    testWidgets('Profile → Payment history opens the history screen', (tester) async {
      await signIn(tester, studentBackend());
      await pumpApp(tester, const HomeShell());

      await tester.tap(find.byKey(const Key('nav_2')));
      await tester.pump(const Duration(milliseconds: 300));
      final row = find.text('Payment history');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await _wait(tester);

      expect(find.byType(PaymentHistoryScreen), findsOneWidget);
      expect(find.text('Ride · EB-021'), findsOneWidget);
    });
  });
}
