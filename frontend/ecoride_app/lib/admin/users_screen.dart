// แท็บ Users: ค้นหานักศึกษา, ดูประวัติยืม/เงิน, แก้ชื่อ-รหัส (ผู้ใช้แก้เองไม่ได้),
// ปรับเครดิต (คืนเงิน/แก้ยอด), ระงับ-เปิดบัญชี
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import 'admin_ui.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';
import '../widgets/form.dart';
import 'sheets.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final q = _q.toLowerCase();
        final list = s.students
            .where((u) =>
                q.isEmpty ||
                u.fullName.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q) ||
                u.studentId.contains(q))
            .toList();
        return Column(
          children: [
            TabHeader('Users', subtitle: '${s.students.length} students'),
            Padding(
              padding: EdgeInsets.fromLTRB(14.px, 2.px, 14.px, 6.px),
              child: TextField(
                onChanged: (t) => setState(() => _q = t.trim()),
                style: ts(12),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: C.inputBg,
                  hintText: 'Search name, username or student ID',
                  hintStyle: ts(12, color: C.muted),
                  prefixIcon: Icon(TablerIcons.search, size: 14.px, color: C.chipText),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.px, vertical: 10.px),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 16.px),
                children: gapped([
                  if (list.isEmpty) Text('No users found', style: muStyle),
                  for (final u in list) _UserRow(u),
                ], h: 8),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.u, {this.size = 34});
  final User u;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.px,
      height: size.px,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: u.isActive ? C.goldBg : C.grayPillBg),
      child: Text(u.initials,
          style: ts(size * 0.36, w: FontWeight.w600, color: u.isActive ? C.red : C.grayPillText)),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow(this.u);
  final User u;

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    final riding = s.ridesOf(u).any((r) => r.isOpen);
    return AppCard(
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailScreen(user: u))),
      children: [
        _Avatar(u),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.fullName, style: ts(12, w: FontWeight.w500)),
              Text('${u.studentId} · ${u.username}', style: muStyle),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(baht(u.creditBalance),
                style: ts(12,
                    w: FontWeight.w600,
                    color: u.creditBalance < s.defaultPlan.price ? C.redText : C.goldText)),
            if (!u.isActive)
              const Pill('Disabled', kind: PillKind.gray)
            else if (riding)
              const Pill('Riding', kind: PillKind.red),
          ],
        ),
      ],
    );
  }
}

// ======================================================================= User detail
class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final u = user;
        final rides = s.ridesOf(u);
        final txns = s.txnsOf(u);
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                TopBar(
                  title: 'User',
                  trailing: IconButton(
                    tooltip: 'Edit details',
                    onPressed: () => _edit(context, u),
                    icon: Icon(TablerIcons.pencil, size: 16.px, color: C.chipText),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 16.px),
                    children: gapped([
                      Row(
                        children: gapped([
                          _Avatar(u, size: 52),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.fullName, style: ts(15, w: FontWeight.w600)),
                                Text('${u.studentId} · ${u.username}', style: muStyle),
                              ],
                            ),
                          ),
                          Pill(u.isActive ? 'Active' : 'Disabled',
                              kind: u.isActive ? PillKind.gold : PillKind.gray),
                        ], w: 10),
                      ),
                      Row(
                        children: gapped([
                          Expanded(
                              child: Kpi(baht(u.creditBalance), 'Credit',
                                  tone: KpiTone.gold, icon: TablerIcons.wallet)),
                          Expanded(
                              child: Kpi('${rides.length}', 'Rides total',
                                  tone: KpiTone.blue, icon: TablerIcons.bike)),
                        ], w: 8),
                      ),
                      Btn('Adjust credit',
                          icon: TablerIcons.plusMinus, onTap: () => _adjust(context, u)),
                      Btn(u.isActive ? 'Disable account' : 'Enable account',
                          kind: BtnKind.outlined, onTap: () async {
                        final ok = await confirmDialog(context,
                            title: u.isActive ? 'Disable ${u.firstName}?' : 'Enable ${u.firstName}?',
                            message: u.isActive
                                ? 'They will not be able to log in or borrow.'
                                : 'They can log in and borrow again.',
                            ok: u.isActive ? 'Disable' : 'Enable');
                        if (!ok || !context.mounted) return;
                        final err = s.setUserActive(u, !u.isActive);
                        if (err != null) toast(context, err, error: true);
                      }),
                      const SectionLabel('Rides'),
                      if (rides.isEmpty) Text('No rides yet', style: muStyle),
                      for (final r in rides.take(10))
                        AppCard(onTap: () => showRideSheet(context, r), children: [
                          TintIc(s.typeOf(s.vehicleById(r.vehicleId)).icon,
                              s.typeOf(s.vehicleById(r.vehicleId)).isBike ? Tint.bike : Tint.scooter),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${s.vehicleById(r.vehicleId).code} · ${dmy(r.startTime)}',
                                    style: ts(12, w: FontWeight.w500)),
                                Text(
                                    '${s.stationById(r.startStationId).name} · ${duration(r.usedTime)}',
                                    style: muStyle),
                              ],
                            ),
                          ),
                          Pill(rideBadge(r).$1, kind: rideBadge(r).$2),
                        ]),
                      const SectionLabel('Credit history'),
                      if (txns.isEmpty) Text('No transactions', style: muStyle),
                      for (final t in txns.take(10))
                        AppCard(children: [
                          TintIc(
                              t.amount >= 0 ? TablerIcons.plus : TablerIcons.minus,
                              t.amount >= 0 ? Tint.ready : Tint.none),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.label, style: ts(12, w: FontWeight.w500)),
                                Text('${t.txnType} · ${dmy(t.createdAt)} ${hm(t.createdAt)}',
                                    style: muStyle),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${t.amount > 0 ? '+' : ''}${baht(t.amount)}',
                                  style: ts(12,
                                      w: FontWeight.w600,
                                      color: t.amount >= 0 ? C.goldText : C.redText)),
                              Text('Bal. ${baht(t.balanceAfter)}',
                                  style: ts(10, color: C.chipText)),
                            ],
                          ),
                        ]),
                    ], h: 9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// แก้ชื่อ / รหัสนักศึกษา (หน้า Account settings ของผู้ใช้ล็อกไว้ ต้องให้แอดมินแก้)
  Future<void> _edit(BuildContext context, User u) async {
    final name = TextEditingController(text: u.fullName);
    final sid = TextEditingController(text: u.studentId);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.px)),
        title: Text('Edit user', style: ts(14, w: FontWeight.w600)),
        content: SizedBox(
          width: 260.px,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: gapped([
              AppInput(controller: name, hint: 'Full name', label: 'Full name'),
              AppInput(
                  controller: sid,
                  hint: 'Student ID',
                  label: 'Student ID',
                  keyboard: TextInputType.number),
              Text('Username cannot be changed (used to log in).', style: muStyle),
            ], h: 10),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: ts(11, color: C.chipText))),
          TextButton(
            onPressed: () {
              final err = AppStore.instance
                  .updateUser(u, fullName: name.text, studentId: sid.text);
              if (err != null) return toast(context, err, error: true);
              Navigator.pop(ctx);
              toast(context, 'User updated');
            },
            child: Text('Save', style: ts(11, w: FontWeight.w600, color: C.red)),
          ),
        ],
      ),
    );
  }

  /// ปรับเครดิต: คืนเงิน (refund) หรือแก้ยอด (adjustment) + เหตุผล → credit_transactions
  Future<void> _adjust(BuildContext context, User u) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    var add = true;
    var refund = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: C.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.px)),
          title: Text('Adjust credit · ${u.firstName}', style: ts(14, w: FontWeight.w600)),
          content: SizedBox(
            width: 260.px,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: gapped([
                Text('Current: ${baht(u.creditBalance)}', style: muStyle),
                Chips(const ['Add (+)', 'Deduct (−)'],
                    selected: add ? 0 : 1, onSelect: (i) => setD(() => add = i == 0)),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: ts(12),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: C.inputBg,
                    prefixText: '฿ ',
                    hintText: 'Amount',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.px), borderSide: BorderSide.none),
                  ),
                ),
                AppInput(controller: reason, hint: 'e.g. Refund – vehicle broke down', label: 'Reason'),
                if (add)
                  Row(children: [
                    Checkbox(
                        value: refund,
                        activeColor: C.red,
                        onChanged: (v) => setD(() => refund = v ?? false)),
                    Expanded(child: Text('This is a refund', style: ts(11))),
                  ]),
              ], h: 8),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: ts(11, color: C.chipText))),
            TextButton(
              onPressed: () {
                final n = double.tryParse(amount.text) ?? 0;
                final err = AppStore.instance
                    .adjustCredit(u, add ? n : -n, reason.text, refund: add && refund);
                if (err != null) return toast(context, err, error: true);
                Navigator.pop(ctx);
                toast(context, 'Credit updated: ${baht(u.creditBalance)}');
              },
              child: Text('Save', style: ts(11, w: FontWeight.w600, color: C.red)),
            ),
          ],
        ),
      ),
    );
  }
}
