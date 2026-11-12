// Widget เฉพาะฝั่ง Admin (แถบเมนูล่าง 5 ปุ่ม, หัวหน้าแดง, ตัวเลขแจ้งเตือน)
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../widgets/basic.dart';

/// แถบเมนูล่าง – ปุ่มที่มีเรื่องค้างจะมีจุดแดงบอกจำนวน
class AdminNavBar extends StatelessWidget {
  const AdminNavBar({super.key, required this.index, required this.onTap, this.badges = const {}});
  final int index;
  final ValueChanged<int> onTap;
  final Map<int, int> badges; // index → จำนวนเรื่องค้าง

  static const items = <(IconData, String)>[
    (TablerIcons.layoutDashboard, 'Overview'),
    (TablerIcons.building, 'Stations'),
    (TablerIcons.scooterElectric, 'Vehicles'),
    (TablerIcons.clipboardList, 'Reports'),
    (TablerIcons.users, 'Users'),
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
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(items[i].$1,
                                size: 18.px, color: i == index ? C.red : C.chipText),
                            if ((badges[i] ?? 0) > 0)
                              Positioned(
                                right: -8.px,
                                top: -4.px,
                                child: CountDot(badges[i]!),
                              ),
                          ],
                        ),
                        Text(items[i].$2,
                            style: ts(10.5,
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

/// วงกลมแดงเล็กบอกจำนวน
class CountDot extends StatelessWidget {
  const CountDot(this.n, {super.key});
  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 15.px),
      padding: EdgeInsets.symmetric(horizontal: 4.px, vertical: 1.px),
      decoration: BoxDecoration(
        color: C.red,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: C.cream, width: 1.5.px),
      ),
      child: Text('$n',
          textAlign: TextAlign.center,
          style: ts(9, w: FontWeight.w600, color: Colors.white)),
    );
  }
}

/// หัวหน้าจอของแต่ละแท็บ (ชื่อหน้า + คำอธิบาย + ปุ่มขวา)
class TabHeader extends StatelessWidget {
  const TabHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.px, 12.px, 10.px, 6.px),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ts(17, w: FontWeight.w600)),
                  if (subtitle != null) Text(subtitle!, style: muStyle),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// ปุ่มวงกลมแดง + (เพิ่มรายการ)
class AddCircle extends StatelessWidget {
  const AddCircle({super.key, required this.onTap, this.tooltip = 'Add'});
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 34.px,
          height: 34.px,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: C.red),
          child: Icon(TablerIcons.plus, size: 18.px, color: Colors.white),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ ป้ายสถานะ (ใช้ซ้ำหลายหน้า)

/// สถานะรถ + สีไอคอนตามประเภท
(String, PillKind) vehicleBadge(Vehicle v) {
  final s = AppStore.instance;
  return switch (v.status) {
    VehicleStatus.inUse => ('In use', PillKind.solid),
    VehicleStatus.maintenance => ('Repair', PillKind.gray),
    VehicleStatus.available =>
      s.liveBattery(v) < AppStore.minBattery ? ('Charging', PillKind.red) : ('Ready', PillKind.gold),
  };
}

Tint vehicleTint(Vehicle v) {
  final s = AppStore.instance;
  if (v.status == VehicleStatus.maintenance) return Tint.off;
  if (v.status == VehicleStatus.available && s.liveBattery(v) < AppStore.minBattery) {
    return Tint.none;
  }
  return s.typeOf(v).isBike ? Tint.bike : Tint.scooter;
}

(String, PillKind) reportBadge(String status) => switch (status) {
      'open' => ('Open', PillKind.red),
      'in_progress' => ('In progress', PillKind.gold),
      _ => ('Resolved', PillKind.gray),
    };

(String, PillKind) rideBadge(Ride r) => r.isOverdue
    ? ('Overdue', PillKind.solid)
    : r.isOpen
        ? ('Riding', PillKind.red)
        : ('Returned', PillKind.gold);

/// "5 min ago", "3 h ago", "2 days ago"
String ago(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  final h = m ~/ 60;
  if (h < 24) return '$h h ago';
  return '${h ~/ 24} ${h ~/ 24 == 1 ? 'day' : 'days'} ago';
}
