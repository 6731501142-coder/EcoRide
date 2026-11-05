import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('EcoRide app smoke test', (WidgetTester tester) async {
    // โหลดแอป EcoRide
    await tester.pumpWidget(const EcoRideApp());

    // ตรวจสอบว่าหน้าแรกเปิดขึ้นมาเจอข้อความ Home (placeholder)
    expect(find.text('Home (placeholder)'), findsOneWidget);
  });
}