// ระบบสเกลขนาด + helper สำหรับสไตล์ตัวอักษรและการจัดช่องว่าง
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'colors.dart';

/// ต้นแบบ HTML ออกแบบที่ความกว้างหน้าจอ ~250px
/// ทุกขนาด (ฟอนต์, padding, radius) ถูกคูณด้วยสเกลนี้ เพื่อให้สัดส่วนเหมือนต้นแบบ 1:1 ทุกเครื่อง
class Ui {
  static const double designWidth = 250;
  static double k = 1.5;

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

TextStyle get ttStyle => ts(12, w: FontWeight.w500); // .tt
TextStyle get muStyle => ts(11, color: C.muted); // .mu

List<Widget> gapped(List<Widget> items, {double h = 0, double w = 0}) => [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) SizedBox(height: h.px, width: w.px),
        items[i],
      ],
    ];
