// EcoRide Admin – จุดเริ่มต้นของแอปฝั่ง Admin
// ธีมแดง-ทองใช้ไฟล์ core/colors.dart + core/ui.dart ชุดเดียวกับฝั่ง User
// (คัดลอกมาจาก frontend/home_vehicle_station) เพื่อให้หน้าตาเหมือนกัน
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/colors.dart';
import 'screens/admin_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  runApp(const EcoRideAdminApp());
}

class EcoRideAdminApp extends StatelessWidget {
  const EcoRideAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRide Admin',
      debugShowCheckedModeBanner: false,
      // จำกัดความกว้างไว้ 460px ให้ดูเหมือนมือถือเวลาเปิดบน Chrome (เหมือนของเพื่อน)
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFF3ECEA),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ClipRect(child: child),
          ),
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: C.cream,
        splashFactory: NoSplash.splashFactory,
        colorScheme: ColorScheme.fromSeed(seedColor: C.red),
      ),
      home: const AdminShell(),
    );
  }
}
