// EcoRide – จุดเริ่มต้นของแอป
// pubspec.yaml ต้องมี:
//   dependencies:
//     flutter:
//       sdk: flutter
//     tabler_icons_plus: ^3.49.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/colors.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  runApp(const EcoRideApp());
}

class EcoRideApp extends StatelessWidget {
  const EcoRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRide',
            debugShowCheckedModeBanner: false,
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
      home: const HomeScreen(),
    );
  }
}


