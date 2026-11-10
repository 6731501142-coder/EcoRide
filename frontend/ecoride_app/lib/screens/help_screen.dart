// ปุ่ม "Need help?" ในหน้า Summary (ระหว่างยืม) → เรียกเจ้าหน้าที่หน้างานมาหา
// ใช้ตอนฉุกเฉิน: อุบัติเหตุ, ยางรั่ว, เบรกไม่ทำงาน, รถพัง, แบตหมดกลางทาง
// (ต่างจาก "Report & feedback" ในหน้า Profile ที่แจ้งปัญหาของแอปให้ admin แบบไม่ด่วน)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';
import '../widgets/form.dart';

/// เบอร์เจ้าหน้าที่ – ใส่เบอร์จริงตรงนี้ที่เดียว
const String staffPhone = '[STAFF PHONE]';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, required this.ride});
  final Ride ride;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  HelpType? _type;
  final _where = TextEditingController();
  final _details = TextEditingController();
  int? _requestNo; // ส่งแล้ว → โชว์หน้าสำเร็จ

  @override
  void dispose() {
    _where.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final type = _type;
    if (type == null) return toast(context, 'Please choose what happened', error: true);
    final ok = await confirmDialog(context,
        title: 'Call staff now?',
        message: 'Staff will be sent to "${_where.text.trim()}".',
        ok: 'Call staff');
    if (!ok || !mounted) return;
    final (no, err) = AppStore.instance.requestHelp(
        ride: widget.ride, type: type, location: _where.text, details: _details.text);
    if (err != null) return toast(context, err, error: true);
    setState(() => _requestNo = no);
  }

  void _copyPhone() {
    Clipboard.setData(const ClipboardData(text: staffPhone));
    toast(context, 'Phone number copied');
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final v = store.vehicleById(widget.ride.vehicleId);
    return Scaffold(
      body: Column(
        children: [
          // ---------- หัวแดง: ฉุกเฉิน + เบอร์เจ้าหน้าที่
          RedHeader(
            padding: EdgeInsets.fromLTRB(8.px, 6.px, 14.px, 16.px),
            child: Column(
              children: [
                Row(
                  children: [
                    const BackIcon(color: Colors.white),
                    Expanded(
                      child: Text('Need help?',
                          textAlign: TextAlign.center,
                          style: ts(14, w: FontWeight.w600, color: Colors.white)),
                    ),
                    SizedBox(width: 34.px),
                  ],
                ),
                Container(
                  margin: EdgeInsets.only(left: 6.px, top: 6.px),
                  padding: EdgeInsets.fromLTRB(12.px, 10.px, 8.px, 10.px),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16.px)),
                  child: Row(
                    children: gapped([
                      Container(
                        width: 36.px,
                        height: 36.px,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: C.red),
                        child: Icon(TablerIcons.phone, size: 18.px, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EcoRide staff hotline', style: ts(10, color: C.chipText)),
                            Text(staffPhone, style: ts(15, w: FontWeight.w700, color: C.red)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _copyPhone,
                        child: Text('Copy', style: ts(11, w: FontWeight.w600, color: C.red)),
                      ),
                    ], w: 10),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _requestNo == null ? _form(v) : _sent(v)),
        ],
      ),
    );
  }

  // ---------- ฟอร์มแจ้งเหตุ
  Widget _form(Vehicle v) {
    final type = _type;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(14.px, 12.px, 14.px, 12.px),
            children: gapped([
              Text('What happened to ${v.code}?', style: ts(13, w: FontWeight.w500)),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8.px,
                crossAxisSpacing: 8.px,
                childAspectRatio: 1.05,
                children: [
                  for (final t in HelpType.values)
                    _TypeTile(t, selected: t == type, onTap: () => setState(() => _type = t)),
                ],
              ),
              // อุบัติเหตุ → เตือนให้โทรสายด่วนการแพทย์ก่อน
              if (type == HelpType.accident)
                Container(
                  padding: EdgeInsets.all(10.px),
                  decoration: BoxDecoration(
                      color: C.redBg, borderRadius: BorderRadius.circular(14.px)),
                  child: Row(
                    children: gapped([
                      Icon(TablerIcons.firstAidKit, size: 18.px, color: C.red),
                      Expanded(
                        child: Text(
                            'If anyone is hurt, call 1669 (emergency medical) first, '
                            'then send this request.',
                            style: ts(11, w: FontWeight.w500, color: C.redText)),
                      ),
                    ], w: 8),
                  ),
                ),
              AppInput(
                  controller: _where,
                  hint: 'e.g. in front of Building 2, near the canteen',
                  label: 'Where are you now?',
                  icon: TablerIcons.mapPin),
              AppInput(
                  controller: _details,
                  hint: 'Anything staff should know (optional)',
                  label: 'Details',
                  maxLines: 3),
            ], h: 10),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.px, 0, 14.px, 12.px),
            child: Btn('Call staff to my location',
                key: const Key('btn_call_staff'), icon: TablerIcons.urgent, onTap: _send),
          ),
        ),
      ],
    );
  }

  // ---------- ส่งแล้ว
  Widget _sent(Vehicle v) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(18.px, 24.px, 18.px, 12.px),
            children: gapped([
              Center(
                child: Container(
                  width: 64.px,
                  height: 64.px,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: C.goldBg),
                  child: Icon(TablerIcons.circleCheck, size: 34.px, color: C.goldIcon),
                ),
              ),
              Text('Staff have been notified',
                  textAlign: TextAlign.center, style: ts(16, w: FontWeight.w600)),
              Text('Request #$_requestNo · ${_type!.label} · ${v.code}',
                  textAlign: TextAlign.center, style: muStyle),
              Panel(
                child: Column(
                  children: [
                    InfoRow('Location', _where.text.trim()),
                    InfoRow('What to do', 'Stay with the vehicle', last: true),
                  ],
                ),
              ),
              Text(
                  'If you cannot wait or the situation gets worse, '
                  'call the staff hotline above.',
                  textAlign: TextAlign.center,
                  style: muStyle),
            ], h: 10),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.px, 0, 14.px, 12.px),
            child: Btn('Back to my ride',
                kind: BtnKind.outlined, onTap: () => Navigator.of(context).pop()),
          ),
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile(this.t, {required this.selected, required this.onTap});
  final HelpType t;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(6.px),
        decoration: BoxDecoration(
          color: selected ? C.red : Colors.white,
          border: Border.all(color: selected ? C.red : C.line, width: 1.2.px),
          borderRadius: BorderRadius.circular(16.px),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: gapped([
            Icon(t.icon, size: 22.px, color: selected ? Colors.white : C.red),
            Text(t.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: ts(10.5, w: FontWeight.w500, color: selected ? Colors.white : C.ink)),
          ], h: 4),
        ),
      ),
    );
  }
}
