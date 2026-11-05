// แถบนำทาง: TopBar (บน), BackIcon, NavBar (เมนูล่าง)
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';

/// .tb – แถบหัวข้อด้านบน
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.leading, this.trailing});
  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.px, vertical: 6.px),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          leading ?? SizedBox(width: 14.px),
          Text(title, style: ts(13, w: FontWeight.w500)),
          trailing ?? SizedBox(width: 14.px),
        ],
      ),
    );
  }
}

class BackIcon extends StatelessWidget {
  const BackIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Icon(TablerIcons.arrowLeft, size: 13.px, color: C.ink),
    );
  }
}

/// .nv – แถบเมนูล่าง
class NavBar extends StatelessWidget {
  const NavBar({super.key, this.index = 0});
  final int index;

  static const _items = <(IconData, String)>[
    (TablerIcons.home, 'Home'),
    (TablerIcons.qrcode, 'Scan'),
    (TablerIcons.history, 'History'),
    (TablerIcons.user, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 6.px, bottom: 8.px),
      decoration: BoxDecoration(
        color: C.cream,
        border: Border(top: BorderSide(color: C.line, width: 1.px)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _items.length; i++)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_items[i].$1, size: 17.px, color: i == index ? C.red : C.hint),
                  Text(
                    _items[i].$2,
                    style: ts(11,
                        w: i == index ? FontWeight.w500 : FontWeight.w400,
                        color: i == index ? C.red : C.hint),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
