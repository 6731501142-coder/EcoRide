// จุดเริ่มแอป EcoRide (ฝั่งผู้ใช้)
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'core/colors.dart';
import 'screens/auth_screens.dart';

void main() => runApp(const EcoRideApp());

class EcoRideApp extends StatelessWidget {
  const EcoRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRide',
      debugShowCheckedModeBanner: false,
      // ให้ลากเลื่อนด้วยเมาส์ได้ (ปกติบนคอม Flutter เลื่อนแนวนอนได้แค่นิ้ว/ทัชแพด)
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      }),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: C.red, primary: C.red),
        scaffoldBackgroundColor: C.cream,
        useMaterial3: true,
      ),
      // เปิดบน Chrome/Windows จอกว้าง → บีบให้กว้างเท่ามือถือ (ไม่เกิน 460px) ไว้ตรงกลาง
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFF3ECEA),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: child,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
