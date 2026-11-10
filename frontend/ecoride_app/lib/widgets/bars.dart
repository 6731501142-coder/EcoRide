// แถบนำทาง: TopBar (หัวหน้าย่อย), BackIcon, RedHeader (หัวแดงโค้ง), AppNavBar (เมนูล่าง 3 แท็บ)
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';

/// แถบหัวข้อบนพื้นครีม: ปุ่มย้อนกลับ | ชื่อหน้า | (ว่าง)
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.trailing, this.onBack});
  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.px, 4.px, 4.px, 4.px),
      child: Row(
        children: [
          BackIcon(onTap: onBack),
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center, style: ts(13, w: FontWeight.w500)),
          ),
          SizedBox(width: 34.px, child: trailing),
        ],
      ),
    );
  }
}

class BackIcon extends StatelessWidget {
  const BackIcon({super.key, this.color = C.ink, this.onTap});
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: onTap ?? () => Navigator.of(context).maybePop(),
      icon: Icon(TablerIcons.arrowLeft, size: 16.px, color: color),
    );
  }
}

/// หัวแดงโค้งด้านล่าง (Login, Home, Profile, Ride summary)
class RedHeader extends StatelessWidget {
  const RedHeader({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.fromLTRB(14.px, 14.px, 14.px, 16.px),
      decoration: BoxDecoration(
        color: C.red,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24.px)),
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

/// เมนูล่าง: Home · History · Profile (ตัด Scan ออกตาม flow ใหม่)
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const items = <(IconData, String)>[
    (TablerIcons.home, 'Home'),
    (TablerIcons.history, 'History'),
    (TablerIcons.user, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 5.px, bottom: 6.px),
      decoration: BoxDecoration(
        color: C.cream,
        border: Border(top: BorderSide(color: C.line, width: 1.px)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  key: Key('nav_$i'),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 3.px),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i].$1,
                            size: 18.px, color: i == index ? C.red : C.chipText),
                        Text(items[i].$2,
                            style: ts(11,
                                w: i == index ? FontWeight.w500 : FontWeight.w400,
                                color: i == index ? C.red : C.chipText)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
