import 'package:flutter/material.dart';
import 'return_station_page.dart';
//import 'borrowing_history_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoRide',
      theme: ThemeData(
        fontFamily: 'Kanit',
        useMaterial3: true,
      ),
      // -------------------------------------------------------------
      // 📍 ต้องการดูหน้าไหน ให้เปิดคอมเมนต์ (ลบ //) ที่หน้านั้นได้เลยครับ
      // -------------------------------------------------------------
      home: const ChooseReturnStationPage(), // 1. หน้าเลือกสถานีคืนรถ (ข้อ 8)
      //home: const BorrowingHistoryPage(),    // 2. หน้าประวัติการยืม-คืน (ข้อ 9)
    );
  }
}