// แผ่นรายละเอียดที่เลื่อนขึ้นจากด้านล่าง (ใช้ได้จากทุกหน้า): issue, ride, top-up, feedback, vehicle
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import 'admin_ui.dart';
import '../widgets/basic.dart';
import '../widgets/form.dart';

/// โครงแผ่นด้านล่าง: เลื่อนได้ ไม่ล้นจอ และอัปเดตเองเมื่อข้อมูลเปลี่ยน
Future<void> showAdminSheet(BuildContext context, List<Widget> Function(BuildContext) build) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
    backgroundColor: C.cream,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.px))),
    builder: (ctx) => ListenableBuilder(
      listenable: AppStore.instance,
      builder: (ctx, _) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.px, 14.px, 16.px, 12.px),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: gapped(build(ctx), h: 10),
          ),
        ),
      ),
    ),
  );
}

Widget _head(IconData icon, Tint tint, String title, String sub, (String, PillKind) badge) => Row(
      children: gapped([
        TintIc(icon, tint, size: 38),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ts(14, w: FontWeight.w600)),
              Text(sub, style: muStyle),
            ],
          ),
        ),
        Pill(badge.$1, kind: badge.$2),
      ], w: 10),
    );

Widget _close(BuildContext ctx) =>
    Btn('Close', kind: BtnKind.outlined, onTap: () => Navigator.of(ctx).pop());

// ======================================================================= Issue (problem_reports)
void showReportSheet(BuildContext context, ProblemReport r) {
  final s = AppStore.instance;
  showAdminSheet(context, (ctx) {
    final v = s.vehicleById(r.vehicleId);
    final u = s.userById(r.userId);
    final urgent = r.isUrgent;
    // ข้อความจาก Need help? = "[URGENT] Flat tyre · at: ที่อยู่ · รายละเอียด"
    final text = (r.details ?? '').replaceFirst('[URGENT] ', '');
    return [
      _head(urgent ? TablerIcons.urgent : TablerIcons.alertTriangle,
          urgent ? Tint.none : Tint.few,
          urgent ? 'Need help · ${v.code}' : 'Problem · ${v.code}',
          '${r.category.label} · ${ago(r.createdAt)}', reportBadge(r.status)),
      if (urgent && r.status != 'resolved')
        Container(
          padding: EdgeInsets.all(10.px),
          decoration:
              BoxDecoration(color: C.redBg, borderRadius: BorderRadius.circular(14.px)),
          child: Text('Rider is waiting for staff. Send someone to the location below.',
              style: ts(11, w: FontWeight.w500, color: C.redText)),
        ),
      Panel(
        child: Column(children: [
          InfoRow('Reported by', u.fullName),
          InfoRow('Student ID', u.studentId),
          InfoRow('Vehicle', '${v.code} · ${s.typeOf(v).name}'),
          InfoRow('Ride', r.rideId == null ? '—' : '#${r.rideId}'),
          InfoRow('Time', '${dmy(r.createdAt)} · ${hm(r.createdAt)}', last: true),
        ]),
      ),
      Text('Details', style: ts(12, w: FontWeight.w500)),
      Panel(
        padding: EdgeInsets.all(12.px),
        child: Text(text.isEmpty ? '—' : text, style: ts(12)),
      ),
      if (r.status == 'open')
        Btn(urgent ? 'Accept · staff on the way' : 'Start working on it',
            icon: TablerIcons.check, onTap: () => s.setReportStatus(r, 'in_progress')),
      if (r.status != 'resolved')
        Btn('Mark as resolved',
            kind: BtnKind.gold, onTap: () => s.setReportStatus(r, 'resolved')),
      if (r.status != 'resolved' && v.status == VehicleStatus.available)
        Btn('Send ${v.code} to repair',
            icon: TablerIcons.tool, kind: BtnKind.outlined, onTap: () {
          final err = s.setMaintenance(v, true);
          toast(ctx, err ?? '${v.code} moved to repair', error: err != null);
        }),
      if (r.status == 'resolved')
        Btn('Reopen', kind: BtnKind.outlined, onTap: () => s.setReportStatus(r, 'open')),
      _close(ctx),
    ];
  });
}

// ======================================================================= Ride
void showRideSheet(BuildContext context, Ride r) {
  final s = AppStore.instance;
  showAdminSheet(context, (ctx) {
    final v = s.vehicleById(r.vehicleId);
    final u = s.userById(r.userId);
    final overBy = DateTime.now().difference(r.dueTime);
    return [
      _head(s.typeOf(v).icon, s.typeOf(v).isBike ? Tint.bike : Tint.scooter, v.code,
          '${u.fullName} · ${u.studentId}', rideBadge(r)),
      if (r.isOverdue)
        Container(
          padding: EdgeInsets.all(10.px),
          decoration:
              BoxDecoration(color: C.redBg, borderRadius: BorderRadius.circular(14.px)),
          child: Text('Overdue by ${duration(overBy)}. Contact the rider to return it.',
              style: ts(11, w: FontWeight.w500, color: C.redText)),
        ),
      Panel(
        child: Column(children: [
          InfoRow('Station', s.stationById(r.startStationId).name),
          InfoRow('Borrowed', '${dmy(r.startTime)} · ${hm(r.startTime)}'),
          InfoRow('Due', '${dmy(r.dueTime)} · ${hm(r.dueTime)}',
              valueColor: r.isOverdue ? C.red : C.ink),
          InfoRow('Returned',
              r.endTime == null ? '—' : '${dmy(r.endTime!)} · ${hm(r.endTime!)}'),
          InfoRow('Time used', duration(r.usedTime)),
          InfoRow(
              'Battery',
              r.batteryEnd == null
                  ? '${r.batteryStart}% → ${s.liveBattery(v)}% (now)'
                  : '${r.batteryStart}% → ${r.batteryEnd}%'),
          InfoRow('Paid', baht(r.pricePaid), last: true, valueColor: C.red, bold: true),
        ]),
      ),
      _close(ctx),
    ];
  });
}

// ======================================================================= Top-up
void showTopupSheet(BuildContext context, Topup t) {
  final s = AppStore.instance;
  showAdminSheet(context, (ctx) {
    final u = s.userById(t.userId);
    final (label, kind) = switch (t.status) {
      TopupStatus.pending => ('Pending', PillKind.red),
      TopupStatus.paid => ('Paid', PillKind.gold),
      TopupStatus.failed => ('Failed', PillKind.gray),
      TopupStatus.expired => ('Expired', PillKind.gray),
    };
    return [
      _head(TablerIcons.wallet, Tint.ready, '${baht(t.amount)} top-up',
          '${u.fullName} · ${ago(t.createdAt)}', (label, kind)),
      Panel(
        child: Column(children: [
          InfoRow('User', '${u.username} · ${u.studentId}'),
          InfoRow('Method', t.paymentMethod.toUpperCase()),
          InfoRow('Reference', t.referenceCode ?? '—'),
          InfoRow('Requested', '${dmy(t.createdAt)} · ${hm(t.createdAt)}'),
          InfoRow('Paid at', t.paidAt == null ? '—' : '${dmy(t.paidAt!)} · ${hm(t.paidAt!)}'),
          InfoRow('Credit now', baht(u.creditBalance), last: true),
        ]),
      ),
      if (t.status == TopupStatus.pending) ...[
        Text('Check the payment arrived before confirming.', style: muStyle),
        Btn('Confirm payment', icon: TablerIcons.check, onTap: () {
          final err = s.confirmTopup(t); // = sp_confirm_topup
          toast(ctx, err ?? '${baht(t.amount)} added to ${u.firstName}', error: err != null);
        }),
        Btn('Mark as failed', kind: BtnKind.outlined, onTap: () => s.rejectTopup(t)),
      ],
      _close(ctx),
    ];
  });
}

// ======================================================================= Feedback
void showFeedbackSheet(BuildContext context, AppFeedback f) {
  final s = AppStore.instance;
  if (f.status == 'open') s.setFeedbackStatus(f, 'read'); // เปิดอ่าน = อ่านแล้ว
  showAdminSheet(context, (ctx) {
    final u = s.userById(f.userId);
    return [
      _head(TablerIcons.messageReport, Tint.charging, f.topic.label,
          '${u.fullName} · ${ago(f.createdAt)}',
          f.status == 'resolved' ? ('Resolved', PillKind.gray) : ('Read', PillKind.gold)),
      Panel(padding: EdgeInsets.all(12.px), child: Text(f.message, style: ts(12))),
      Text('Reply to ${u.username} outside the app (e.g. email), then mark it resolved.',
          style: muStyle),
      if (f.status != 'resolved')
        Btn('Mark as resolved',
            kind: BtnKind.gold, onTap: () => s.setFeedbackStatus(f, 'resolved')),
      _close(ctx),
    ];
  });
}

// ======================================================================= Vehicle
void showVehicleSheet(BuildContext context, Vehicle v) {
  final s = AppStore.instance;
  showAdminSheet(context, (ctx) {
    final type = s.typeOf(v);
    final pct = s.liveBattery(v);
    final ride = s.openRideOf(v);
    final reports = s.openReports.where((r) => r.vehicleId == v.vehicleId).toList();
    return [
      _head(type.icon, vehicleTint(v), v.code, type.name, vehicleBadge(v)),
      Row(
        children: [
          Text('Battery', style: ts(12, color: C.chipText)),
          if (s.isCharging(v)) ...[
            SizedBox(width: 6.px),
            Icon(TablerIcons.plugConnected, size: 13.px, color: Tint.charging.fg),
            Text(' Charging', style: ts(11, color: Tint.charging.fg)),
          ],
          const Spacer(),
          Text('$pct%', style: ts(12, w: FontWeight.w500)),
        ],
      ),
      Bar(pct, red: pct < AppStore.minBattery),
      Panel(
        child: Column(children: [
          InfoRow('Location',
              v.currentStationId == null ? 'Out on a ride' : s.stationById(v.currentStationId!).name),
          InfoRow('Rider', ride == null ? '—' : s.userById(ride.userId).fullName),
          InfoRow('Open issues', '${reports.length}',
              valueColor: reports.isEmpty ? C.ink : C.red, last: true),
        ]),
      ),
      for (final r in reports)
        AppCard(onTap: () => showReportSheet(ctx, r), children: [
          TintIc(r.isUrgent ? TablerIcons.urgent : TablerIcons.alertTriangle,
              r.isUrgent ? Tint.none : Tint.few),
          Expanded(child: Text(r.category.label, style: ts(12, w: FontWeight.w500))),
          Pill(reportBadge(r.status).$1, kind: reportBadge(r.status).$2),
        ]),
      if (ride != null)
        Btn('View current ride', kind: BtnKind.outlined, onTap: () => showRideSheet(ctx, ride)),
      if (v.status == VehicleStatus.available)
        Btn('Send to repair', icon: TablerIcons.tool, onTap: () {
          final err = s.setMaintenance(v, true);
          if (err != null) toast(ctx, err, error: true);
        }),
      if (v.status == VehicleStatus.maintenance)
        Btn('Back in service', icon: TablerIcons.check, kind: BtnKind.gold, onTap: () {
          if (v.currentStationId == null) {
            return toast(ctx, 'Park it at a station first', error: true);
          }
          s.setMaintenance(v, false);
        }),
      _close(ctx),
    ];
  });
}
