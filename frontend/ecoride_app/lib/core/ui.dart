// ระบบสเกลขนาด + helper สำหรับสไตล์ตัวอักษรและการจัดช่องว่าง
// (ชุดเดียวกับ home_vehicle_station / admin_ecoride)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'colors.dart';

/// ทุกขนาด (ฟอนต์, padding, radius) เขียนเป็น "หน่วยออกแบบ" แล้วคูณด้วย k
/// k = ความกว้างจอ (สูงสุด 460) / designWidth
class Ui {
  static const double designWidth = 300;
  static double k = 1.3;

  static void init(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    k = math.min(w, 460) / designWidth;
  }
}

extension Px on num {
  double get px => this * Ui.k;
}

TextStyle ts(
  double size, {
  FontWeight w = FontWeight.w400,
  Color color = C.ink,
}) =>
    TextStyle(
      fontSize: size.px,
      fontWeight: w,
      color: color,
      height: 1.35,
      leadingDistribution: TextLeadingDistribution.even,
    );

TextStyle get ttStyle => ts(12, w: FontWeight.w500);
TextStyle get muStyle => ts(11, color: C.chipText);

List<Widget> gapped(List<Widget> items, {double h = 0, double w = 0}) => [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) SizedBox(height: h.px, width: w.px),
        items[i],
      ],
    ];

/// ฿1,000
String baht(num v) {
  final s = v.round().abs().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${v < 0 ? '−' : ''}฿$s';
}

String two(int n) => n.toString().padLeft(2, '0');

/// 05/11/2026
String dmy(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

/// 09:42
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// 1 h 05 min / 23 min
String duration(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${two(m % 60)} min';
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// November 2026 – ใช้เป็นหัวคั่นรายการแต่ละเดือน
String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// แบ่งรายการ (เรียงใหม่→เก่าอยู่แล้ว) เป็นกลุ่มตามเดือน: [(หัวเดือน, รายการ), ...]
List<(String, List<T>)> groupByMonth<T>(List<T> items, DateTime Function(T) dateOf) {
  final out = <(String, List<T>)>[];
  for (final it in items) {
    final key = monthYear(dateOf(it));
    if (out.isEmpty || out.last.$1 != key) out.add((key, <T>[]));
    out.last.$2.add(it);
  }
  return out;
}
