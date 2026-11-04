// Widget เพิ่มเติมสำหรับฝั่ง Admin (ใช้สี/สเกลเดียวกับ core/colors.dart และ core/ui.dart)
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/admin_models.dart';
import 'basic.dart';

/// หัวแดงโค้งด้านล่าง – แบบเดียวกับ Home ของฝั่ง User
class AdminHeader extends StatelessWidget {
  const AdminHeader({super.key, required this.title, this.subtitle, this.trailing, this.child});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child; // เช่น ช่องค้นหา ใต้หัวข้อ

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.px, 6.px, 12.px, 14.px),
      decoration: BoxDecoration(
        color: C.red,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22.px)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      Text(subtitle!,
                          style: ts(11, color: const Color.fromRGBO(255, 255, 255, .85))),
                    Text(title, style: ts(15, w: FontWeight.w500, color: Colors.white)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (child != null) ...[SizedBox(height: 7.px), child!],
        ],
      ),
    );
  }
}

/// แถบเมนูล่างของ Admin – กดเปลี่ยนแท็บได้
class AdminNavBar extends StatelessWidget {
  const AdminNavBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const items = <(IconData, String)>[
    (TablerIcons.layoutDashboard, 'Dashboard'),
    (TablerIcons.mapPin, 'Stations'),
    (TablerIcons.bike, 'Vehicles'),
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
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  key: Key('admin_nav_$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i].$1, size: 17.px, color: i == index ? C.red : C.hint),
                      Text(
                        items[i].$2,
                        style: ts(11,
                            w: i == index ? FontWeight.w500 : FontWeight.w400,
                            color: i == index ? C.red : C.hint),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ช่องค้นหาที่พิมพ์ได้จริง
class AdminSearch extends StatelessWidget {
  const AdminSearch({super.key, required this.hint, required this.onChanged, this.bg = Colors.white});
  final String hint;
  final ValueChanged<String> onChanged;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.px),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        children: [
          Icon(TablerIcons.search, size: 11.px, color: C.hint),
          SizedBox(width: 4.px),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: ts(11),
              cursorColor: C.red,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: ts(11, color: C.hint),
                contentPadding: EdgeInsets.symmetric(vertical: 9.px),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ช่องกรอกข้อมูลในฟอร์ม (สไตล์เดียวกับหน้า Create account)
class AdminField extends StatelessWidget {
  const AdminField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.number = false,
    this.decimal = false,
    this.validator,
  });
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool number;
  final bool decimal;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.px),
          borderSide: BorderSide(color: c, width: 1.px),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ts(11, color: C.muted)),
        SizedBox(height: 3.px),
        TextFormField(
          controller: controller,
          validator: validator,
          style: ts(12),
          cursorColor: C.red,
          keyboardType: number
              ? TextInputType.numberWithOptions(decimal: decimal, signed: decimal)
              : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: C.inputBg,
            hintText: hint,
            hintStyle: ts(11, color: C.hint),
            errorStyle: ts(10, color: C.redText),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.px, vertical: 10.px),
            border: border(Colors.transparent),
            enabledBorder: border(Colors.transparent),
            focusedBorder: border(C.gold),
            errorBorder: border(C.red),
            focusedErrorBorder: border(C.red),
          ),
        ),
      ],
    );
  }
}

/// หัวข้อย่อยในหน้า
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: ts(12, w: FontWeight.w500))),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: ts(11, color: C.red)),
          ),
      ],
    );
  }
}

/// pill สีตามสถานะรถ
class VehicleStatusPill extends StatelessWidget {
  const VehicleStatusPill(this.status, {super.key});
  final VehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final kind = switch (status) {
      VehicleStatus.available => PillKind.gold,
      VehicleStatus.borrowed => PillKind.solid,
      VehicleStatus.maintenance => PillKind.red,
      VehicleStatus.unavailable => PillKind.gray,
    };
    return Pill(status.label, kind: kind);
  }
}

/// กล่องยืนยันก่อนลบ/ปิด (กันกดพลาด)
Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String ok = 'Confirm'}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.px)),
      title: Text(title, style: ts(13, w: FontWeight.w500)),
      content: Text(message, style: ts(11, color: C.muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: ts(11, color: C.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok, style: ts(11, w: FontWeight.w500, color: C.red)),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// แจ้งผลด้านล่างจอ (สำเร็จ = ทอง, error = แดง)
void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? C.red : C.ink,
      content: Text(msg, style: ts(11, color: Colors.white)),
    ));
}
