import 'package:flutter/material.dart';

/// พาเลตสี "แดง-ทอง" ของ EcoRide
/// ทุกหน้าในทีมควรใช้ไฟล์นี้ร่วมกัน เพื่อให้สีตรงกันทั้งแอป
class AppColors {
  AppColors._();

  static const crimson = Color(0xFFC8313E); // แดงหลัก (header, ปุ่มหลัก)
  static const gold = Color(0xFFE3A91B); // ทอง (ไอคอน, กรอบสแกน, แถบแบต)
  static const goldDark = Color(0xFF7A5A0A); // ตัวอักษรบนพื้นทองอ่อน
  static const goldSoft = Color(0xFFFBEFD8); // พื้นทองอ่อน (ชิป, วงกลมไอคอน)
  static const blush = Color(0xFFFCE4E6); // พื้นชมพูอ่อน (Low / Unavailable)
  static const cream = Color(0xFFFFFAF6); // พื้นหลังแอป
  static const border = Color(0xFFF1DEDE); // เส้นขอบการ์ด
  static const ink = Color(0xFF3A1D22); // ตัวอักษรหลัก
  static const muted = Color(0xFF8C7A7E); // ตัวอักษรรอง
  static const scanBg = Color(0xFF241717); // พื้นหลังหน้าสแกน (โทนเข้ม)
}
