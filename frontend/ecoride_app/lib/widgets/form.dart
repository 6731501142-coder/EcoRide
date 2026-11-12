// ช่องกรอก, แถวข้อมูล, toast และกล่องยืนยัน ที่ใช้ร่วมกันหลายหน้า
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';

/// ช่องกรอกทรงแคปซูลพื้นชมพูอ่อน (เหมือนหน้า Login/Create account ต้นแบบ)
/// ช่องรหัสผ่าน (obscure: true) จะมีปุ่มรูปตาให้กดดู/ซ่อนรหัสอัตโนมัติ
class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.icon,
    this.obscure = false,
    this.keyboard,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboard;
  final int maxLines;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late bool _hidden = widget.obscure; // true = ซ่อนรหัส

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final radius = BorderRadius.circular(w.maxLines > 1 ? 16.px : 99);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: radius, borderSide: BorderSide(color: c, width: 1.px));
    final field = TextField(
      controller: w.controller,
      obscureText: _hidden,
      keyboardType: w.keyboard,
      maxLines: w.obscure ? 1 : w.maxLines,
      style: ts(12),
      cursorColor: C.red,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: C.inputBg,
        hintText: w.hint,
        hintStyle: ts(12, color: C.muted),
        prefixIcon: w.icon == null ? null : Icon(w.icon, size: 14.px, color: C.chipText),
        // ปุ่มรูปตา: กดสลับดู/ซ่อนรหัสผ่าน
        suffixIcon: !w.obscure
            ? null
            : IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(_hidden ? TablerIcons.eye : TablerIcons.eyeOff,
                    size: 16.px, color: C.chipText),
              ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.px, vertical: 11.px),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(C.gold),
      ),
    );
    final label = w.label;
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 6.px, bottom: 3.px),
          child: Text(label, style: ts(11, color: C.chipText)),
        ),
        field,
      ],
    );
  }
}

/// หัวข้อย่อยสีทอง เช่น "Personal info"
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: ts(11, w: FontWeight.w500, color: C.goldText));
}

/// แถว "ป้าย ........ ค่า" ในการ์ดสรุป
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value,
      {super.key, this.last = false, this.valueColor = C.ink, this.bold = false});
  final String label;
  final String value;
  final bool last;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 9.px),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: C.lineRow, width: 1.px)),
      ),
      child: Row(
        children: [
          Text(label, style: ts(12, color: C.chipText)),
          const Spacer(),
          Text(value,
              style: ts(12, w: bold ? FontWeight.w600 : FontWeight.w500, color: valueColor)),
        ],
      ),
    );
  }
}

/// กล่องการ์ดสีขาวขอบชมพู ใส่อะไรข้างในก็ได้
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 12.px, vertical: 2.px),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: C.line, width: 1.px),
        borderRadius: BorderRadius.circular(16.px),
      ),
      child: child,
    );
  }
}

/// แจ้งผลด้านล่างจอ (error = แดง)
void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? C.red : C.ink,
      content: Text(msg, style: ts(11, color: Colors.white)),
    ));
}

/// กล่องยืนยันก่อนทำสิ่งสำคัญ (ออกจากระบบ ฯลฯ)
Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String ok = 'Confirm'}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.px)),
      title: Text(title, style: ts(13, w: FontWeight.w500)),
      content: Text(message, style: ts(11, color: C.chipText)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: ts(11, color: C.chipText))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ok, style: ts(11, w: FontWeight.w500, color: C.red))),
      ],
    ),
  );
  return res ?? false;
}

/// หัวคั่นเดือน เช่น "November 2026" ในหน้า History / Payment history
class MonthHeader extends StatelessWidget {
  const MonthHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4.px),
      child: Row(
        children: [
          Text(text, style: ts(12, w: FontWeight.w600, color: C.redText)),
          SizedBox(width: 8.px),
          Expanded(child: Container(height: 1.px, color: C.chipLine)),
        ],
      ),
    );
  }
}
