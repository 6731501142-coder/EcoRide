// หน้าที่เปิดจาก Profile: Account settings, Report a problem, Add credit, Payment history
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

// ======================================================================= หน้า 12 Account settings
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _current = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_current, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  /// ข้อมูลส่วนตัว (ชื่อ, รหัสนักศึกษา, username) แก้ไม่ได้ – ผูกกับทะเบียนนักศึกษา
  /// หน้านี้เปลี่ยนได้แค่รหัสผ่าน
  Future<void> _save() async {
    final err =
        await AppStore.instance.changePassword(_current.text, _pass.text, _confirm.text);
    if (!mounted) return;
    if (err != null) return toast(context, err, error: true);
    toast(context, 'Password updated');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = AppStore.instance.me!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Account settings'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(18.px, 4.px, 18.px, 12.px),
                children: gapped([
                  const SectionLabel('Personal info'),
                  _LockedField('Full name', me.fullName),
                  _LockedField('Student ID', me.studentId),
                  _LockedField('Username', me.username),
                  Text('These details are linked to your student record and cannot be changed. '
                      'Contact staff if something is wrong.',
                      style: muStyle),
                  SizedBox(height: 4.px),
                  const SectionLabel('Change password'),
                  AppInput(controller: _current, hint: 'Current password', obscure: true),
                  AppInput(controller: _pass, hint: 'New password', obscure: true),
                  AppInput(controller: _confirm, hint: 'Confirm new password', obscure: true),
                ], h: 9),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18.px, 0, 18.px, 12.px),
              child: Btn('Change password', key: const Key('btn_save_account'), onTap: _save),
            ),
          ],
        ),
      ),
    );
  }
}

/// ช่องแสดงข้อมูลแบบล็อก (ดูได้ แก้ไม่ได้) มีรูปกุญแจทางขวา
class _LockedField extends StatelessWidget {
  const _LockedField(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 6.px, bottom: 4.px),
          child: Text(label, style: ts(11, color: C.chipText)),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.px, vertical: 11.px),
          decoration: BoxDecoration(
            color: const Color(0xFFF1ECEB),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value, style: ts(12, color: C.chipText))),
              Icon(TablerIcons.lock, size: 14.px, color: C.muted),
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================================= Report & feedback (จาก Profile)
// แจ้งปัญหาของ "แอป" หรือข้อเสนอแนะ → ส่งถึง admin (ไม่ใช่เรื่องด่วน)
// ถ้ารถมีปัญหาระหว่างขี่ ให้ใช้ปุ่ม "Need help?" ในหน้า Summary แทน
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  FeedbackTopic _topic = FeedbackTopic.appBug;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final err = await AppStore.instance.submitFeedback(topic: _topic, message: _message.text);
    if (!mounted) return;
    if (err != null) return toast(context, err, error: true);
    toast(context, 'Thanks! Our team will look into it.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Report & feedback'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 12.px),
                children: gapped([
                  Container(
                    padding: EdgeInsets.all(10.px),
                    decoration: BoxDecoration(
                        color: C.goldBg, borderRadius: BorderRadius.circular(14.px)),
                    child: Row(
                      children: gapped([
                        Icon(TablerIcons.messageCircle, size: 18.px, color: C.goldIcon),
                        Expanded(
                          child: Text(
                              'Found a problem in the app or have an idea? Tell the EcoRide team.',
                              style: ts(11, color: C.kpText)),
                        ),
                      ], w: 8),
                    ),
                  ),
                  Text('Topic', style: ts(12, w: FontWeight.w500)),
                  Wrap(
                    spacing: 6.px,
                    runSpacing: 6.px,
                    children: [
                      for (final t in FeedbackTopic.values)
                        ChoiceChip(
                          label: Text(t.label,
                              style: ts(11, color: t == _topic ? Colors.white : C.chipText)),
                          selected: t == _topic,
                          showCheckmark: false,
                          selectedColor: C.red,
                          backgroundColor: C.cream,
                          side: BorderSide(color: t == _topic ? C.red : C.chipLine),
                          shape: const StadiumBorder(),
                          onSelected: (_) => setState(() => _topic = t),
                        ),
                    ],
                  ),
                  AppInput(
                      controller: _message,
                      hint: 'What happened? What did you expect?',
                      label: 'Details',
                      maxLines: 6),
                  Text('Vehicle trouble while riding? Use "Need help?" on your ride page.',
                      style: muStyle),
                ], h: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.px, 0, 14.px, 12.px),
              child: Btn('Send', key: const Key('btn_send_feedback'), onTap: _send),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================= Add credit
class AddCreditScreen extends StatefulWidget {
  const AddCreditScreen({super.key});

  @override
  State<AddCreditScreen> createState() => _AddCreditScreenState();
}

class _AddCreditScreenState extends State<AddCreditScreen> {
  static const _amounts = [100, 200, 500, 1000];
  int _picked = 200;
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  double get _amount {
    final c = double.tryParse(_custom.text.trim());
    return c ?? _picked.toDouble();
  }

  /// สร้างคำขอเติมเงิน (topups) → จ่าย QR → sp_confirm_topup
  /// ตอนนี้จำลองว่าจ่ายสำเร็จทันที (ตัวจริง: รอระบบจ่ายเงิน/แอดมินยืนยัน)
  bool _busy = false; // กันกดซ้ำระหว่างรอ backend

  Future<void> _topUp() async {
    if (_busy) return;
    final amt = _amount;
    if (amt < AppStore.minTopup) {
      return toast(context, 'Minimum top-up is ${baht(AppStore.minTopup)}', error: true);
    }
    if (amt > AppStore.maxTopup) {
      return toast(context, 'Maximum top-up is ${baht(AppStore.maxTopup)} per time', error: true);
    }
    final store = AppStore.instance;
    _busy = true;
    final (t, createErr) = await store.createTopup(amt);
    // ยังไม่มีระบบจ่ายเงินจริง: backend ให้ผู้ใช้ยืนยันรายการของตัวเองได้ (ALLOW_SELF_CONFIRM_TOPUP)
    final err = t == null ? createErr : await store.confirmTopup(t);
    _busy = false;
    if (!mounted) return;
    if (err != null) return toast(context, err, error: true);
    toast(context, '${baht(amt)} added to your credit');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = AppStore.instance.me!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Add credit'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 12.px),
                children: gapped([
                  Kpi(baht(me.creditBalance), 'Current credit',
                      tone: KpiTone.gold, icon: TablerIcons.wallet),
                  Text('Choose amount', style: ts(12, w: FontWeight.w500)),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8.px,
                    crossAxisSpacing: 8.px,
                    childAspectRatio: 3,
                    children: [
                      for (final a in _amounts)
                        _AmountTile(
                          baht(a),
                          selected: _custom.text.isEmpty && _picked == a,
                          onTap: () => setState(() {
                            _picked = a;
                            _custom.clear();
                          }),
                        ),
                    ],
                  ),
                  TextField(
                    controller: _custom,
                    keyboardType: TextInputType.number,
                    // พิมพ์ได้แค่ตัวเลข ไม่เกิน 4 หลัก (สูงสุด ฿5,000 ต่อครั้ง)
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: ts(12),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: C.inputBg,
                      hintText: 'Or enter amount (฿20 – ฿5,000)',
                      hintStyle: ts(12, color: C.muted),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.px, vertical: 11.px),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                    ),
                  ),
                  Text('Pay with', style: ts(12, w: FontWeight.w500)),
                  AppCard(children: [
                    Container(
                      width: 52.px,
                      height: 52.px,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: C.chipLine, width: 1.5.px),
                        borderRadius: BorderRadius.circular(10.px),
                      ),
                      child: Icon(TablerIcons.qrcode, size: 26.px, color: C.chipText),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('[PAYMENT METHOD]', style: ts(12, w: FontWeight.w500)),
                          Text('Scan to pay ${baht(_amount)}. Credit updates after payment.',
                              style: muStyle),
                        ],
                      ),
                    ),
                  ]),
                ], h: 10),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.px, 0, 14.px, 12.px),
              child: Btn('Top up ${baht(_amount)}', key: const Key('btn_topup'), onTap: _topUp),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.redBg : Colors.white,
          border: Border.all(color: selected ? C.red : C.line, width: selected ? 1.6.px : 1.px),
          borderRadius: BorderRadius.circular(16.px),
        ),
        child: Text(label,
            style: ts(13, w: FontWeight.w500, color: selected ? C.redText : C.ink)),
      ),
    );
  }
}

// ======================================================================= Payment history
class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.me!;
        final txns = store.myTransactions;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const TopBar(title: 'Payment history'),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 12.px),
                    children: gapped([
                      Row(
                        children: gapped([
                          Expanded(
                              child: Kpi(baht(me.creditBalance), 'Credit left',
                                  tone: KpiTone.gold, icon: TablerIcons.wallet)),
                          Expanded(
                              child: Kpi(baht(store.monthlyStats.spent), 'Spent this month',
                                  tone: KpiTone.rose, icon: TablerIcons.receipt)),
                        ], w: 8),
                      ),
                      if (txns.isEmpty) Text('No payments yet', style: muStyle),
                      // คั่นแต่ละเดือนด้วยชื่อเดือน + ปี
                      for (final (month, items)
                          in groupByMonth(txns, (CreditTransaction t) => t.createdAt)) ...[
                        MonthHeader(month),
                        for (final t in items)
                        AppCard(children: [
                          Ic(t.isTopup ? TablerIcons.plus : TablerIcons.bike, red: !t.isTopup),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(store.txnLabel(t), style: ts(12, w: FontWeight.w500)),
                                Text('${dmy(t.createdAt)} · ${hm(t.createdAt)}', style: muStyle),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${t.amount > 0 ? '+' : ''}${baht(t.amount)}',
                                  style: ts(12,
                                      w: FontWeight.w600,
                                      color: t.isTopup ? C.goldText : C.redText)),
                              Text('Bal. ${baht(t.balanceAfter)}', style: ts(10, color: C.chipText)),
                            ],
                          ),
                        ]),
                      ],
                    ], h: 8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
