import 'package:flutter/material.dart';
import 'ecoride_colors.dart';
import 'login_page.dart';

void main() {
  runApp(const EcoRideApp());
}

class EcoRideApp extends StatelessWidget {
  const EcoRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRide',
      debugShowCheckedModeBanner: false,
            // จำกัดความกว้าง 460px ให้ดูเป็นมือถือเวลาเปิดบน Chrome
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
        scaffoldBackgroundColor: EcoRideColors.bgWhite,
      ),
      // Default entry point for testing
      home: const LoginPage(), 
    );
  }
}