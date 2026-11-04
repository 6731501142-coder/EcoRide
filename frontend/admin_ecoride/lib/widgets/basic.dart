// Widget พื้นฐานที่ใช้ซ้ำทุกหน้า (ไอคอนวงกลม, pill, การ์ด, แถบแบต, KPI, chips, ช่องค้นหา, ปุ่ม)
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';

/// .ic – วงกลมไอคอน
class Ic extends StatelessWidget {
  const Ic(this.icon, {super.key, this.red = false});
  final IconData icon;
  final bool red;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30.px,
      height: 30.px,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: red ? C.redBg : C.goldBg,
      ),
      child: Icon(icon, size: 16.px, color: red ? C.red : C.goldIcon),
    );
  }
}

/// .pl – pill
enum PillKind { gold, red, gray, solid }

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.kind = PillKind.gold});
  final String text;
  final PillKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      PillKind.gold => (C.goldBg, C.goldText),
      PillKind.red => (C.redBg, C.redText),
      PillKind.gray => (C.grayPillBg, C.grayPillText),
      PillKind.solid => (C.red, Colors.white),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.px, vertical: 1.px),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: ts(11, color: fg), maxLines: 1, softWrap: false),
    );
  }
}

/// .cd – การ์ด
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.children, this.onTap});
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.px),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: C.line, width: 1.px),
          borderRadius: BorderRadius.circular(16.px),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: gapped(children, w: 8),
        ),
      ),
    );
  }
}

/// .bar – แถบแบตเตอรี่
class Bar extends StatelessWidget {
  const Bar(this.pct, {super.key, this.red = false});
  final int pct;
  final bool red;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5.px),
      child: Container(
        height: 5.px,
        color: C.line,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: (pct / 100).clamp(0.0, 1.0).toDouble(),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: red ? C.red : C.gold,
              borderRadius: BorderRadius.circular(5.px),
            ),
          ),
        ),
      ),
    );
  }
}

/// .kp – กล่องตัวเลขสรุป
class Kpi extends StatelessWidget {
  const Kpi(this.value, this.label, {super.key});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.px),
      decoration: BoxDecoration(
        color: C.goldBg,
        borderRadius: BorderRadius.circular(16.px),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: ts(17, w: FontWeight.w500), textAlign: TextAlign.center),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: ts(11, color: C.kpText), maxLines: 1),
          ),
        ],
      ),
    );
  }
}

/// .ch – chips
class Chips extends StatelessWidget {
  const Chips(this.labels, {super.key, required this.selected, required this.onSelect});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: gapped([
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 9.px, vertical: 3.px),
                decoration: BoxDecoration(
                  color: i == selected ? C.red : null,
                  border: Border.all(
                    color: i == selected ? C.red : C.chipLine,
                    width: 1.px,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  labels[i],
                  style: ts(11, color: i == selected ? Colors.white : C.chipText),
                ),
              ),
            ),
        ], w: 5),
      ),
    );
  }
}

/// .in – ช่องค้นหา
class SearchField extends StatelessWidget {
  const SearchField(this.hintText, {super.key, this.bg = C.inputBg});
  final String hintText;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.px, vertical: 9.px),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        children: [
          Icon(TablerIcons.search, size: 11.px, color: C.hint),
          SizedBox(width: 3.px),
          Text(hintText, style: ts(11, color: C.hint)),
        ],
      ),
    );
  }
}

/// .bt – ปุ่ม
enum BtnKind { filled, outlined, gold }

class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.icon, this.kind = BtnKind.filled, this.onTap});
  final String label;
  final IconData? icon;
  final BtnKind kind;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      BtnKind.filled => (C.red, Colors.white),
      BtnKind.outlined => (Colors.white, C.red),
      BtnKind.gold => (C.gold, C.ink),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(10.px),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: kind == BtnKind.outlined
              ? Border.all(color: Color(0xFFE8A9AE), width: 1.5.px)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12.px, color: fg),
              SizedBox(width: 3.px),
            ],
            Text(label, style: ts(12, w: FontWeight.w500, color: fg)),
          ],
        ),
      ),
    );
  }
}
