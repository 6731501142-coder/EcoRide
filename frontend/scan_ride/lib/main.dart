import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'providers/ride_provider.dart';
import 'screens/active_riding_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/scan_qr_screen.dart';

void main() {
  runApp(
    // ใส่ RideProvider ไว้บนสุด เพื่อให้ "ทุกหน้า" อ่านสถานะการยืมได้
    ChangeNotifierProvider(
      create: (_) => RideProvider(),
      child: const EcoRideApp(),
    ),
  );
}

class EcoRideApp extends StatelessWidget {
  const EcoRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,

      // จำกัดความกว้างให้เหมือนหน้าจอมือถือ ตอนรันบน Chrome
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFF3EAEA),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),

      routes: {
        // ===== ของฉัน (หน้า 6, 7) =====
        AppRoutes.scan: (_) => const ScanQrScreen(),
        AppRoutes.riding: (_) => const ActiveRidingScreen(),

        // ===== หน้าของเพื่อน: ตอนนี้เป็นตัวจำลอง ให้เปลี่ยนเป็นหน้าจริงตอนรวมโค้ด =====
        AppRoutes.home: (ctx) => PlaceholderScreen(
              title: 'Home (placeholder)',
              buttonLabel: 'Scan QR to borrow',
              onPressed: () => Navigator.pushNamed(ctx, AppRoutes.scan),
            ),
        AppRoutes.returnStation: (ctx) => PlaceholderScreen(
              title: 'Choose return station',
              buttonLabel: 'Confirm return (จำลอง)',
              onPressed: () {
                ctx.read<RideProvider>().endRide(); // จบการยืม หยุดจับเวลา
                Navigator.pushNamedAndRemoveUntil(
                    ctx, AppRoutes.home, (route) => false);
              },
            ),
        AppRoutes.report: (_) => const PlaceholderScreen(title: 'Report a problem'),
      },
    );
  }
}
