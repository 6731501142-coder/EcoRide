// แท็บ Reports: 4 หมวดที่มาจากการใช้งานฝั่งผู้ใช้
//   Issues   ← ปุ่ม Need help? (ด่วน) + problem_reports
//   Rides    ← การยืม/คืน (rides) – กำลังยืม / เกินเวลา / คืนแล้ว
//   Top-ups  ← การเติมเงิน (topups) – รอยืนยัน / สำเร็จ / ล้มเหลว
//   Feedback ← Report & feedback ในหน้า Profile (app_feedback)
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import 'admin_ui.dart';
import '../widgets/basic.dart';
import '../widgets/form.dart';
import 'sheets.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key, this.initial = 0});
  final int initial;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  late int _sub = widget.initial;
  int _rideFilter = 0; // 0 Open, 1 All

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final labels = [
          'Issues${s.openReports.isEmpty ? '' : ' (${s.openReports.length})'}',
          'Rides${s.overdueRides.isEmpty ? '' : ' (${s.overdueRides.length}!)'}',
          'Top-ups${s.pendingTopups.isEmpty ? '' : ' (${s.pendingTopups.length})'}',
          'Feedback${s.unreadFeedback == 0 ? '' : ' (${s.unreadFeedback})'}',
        ];
        return Column(
          children: [
            const TabHeader('Reports', subtitle: 'Everything riders do in the EcoRide app'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.px),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chips(labels, selected: _sub, onSelect: (i) => setState(() => _sub = i)),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14.px, 10.px, 14.px, 16.px),
                children: gapped(switch (_sub) {
                  0 => _issues(context),
                  1 => _rides(context),
                  2 => _topups(context),
                  _ => _feedback(context),
                }, h: 8),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- Issues
  List<Widget> _issues(BuildContext context) {
    final s = AppStore.instance;
    final list = s.reports;
    if (list.isEmpty) return [Text('No reports', style: muStyle)];
    return [
      Text('Urgent help requests come from the "Need help?" button during a ride.',
          style: muStyle),
      for (final r in list)
        AppCard(onTap: () => showReportSheet(context, r), children: [
          TintIc(r.isUrgent ? TablerIcons.urgent : TablerIcons.alertTriangle,
              r.status == 'resolved' ? Tint.off : (r.isUrgent ? Tint.none : Tint.few)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${r.isUrgent ? 'URGENT · ' : ''}${r.category.label} · '
                    '${s.vehicleById(r.vehicleId).code}',
                    style: ts(12,
                        w: FontWeight.w500, color: r.isUrgent ? C.redText : C.ink)),
                Text('${s.userById(r.userId).fullName} · ${ago(r.createdAt)}',
                    style: muStyle),
              ],
            ),
          ),
          Pill(reportBadge(r.status).$1, kind: reportBadge(r.status).$2),
        ]),
    ];
  }

  // ---------------------------------------------------------------- Rides
  List<Widget> _rides(BuildContext context) {
    final s = AppStore.instance;
    final list = _rideFilter == 0 ? s.openRides : s.allRides;
    return [
      Chips(const ['Out now', 'All rides'],
          selected: _rideFilter, onSelect: (i) => setState(() => _rideFilter = i)),
      if (list.isEmpty) Text('No vehicles are out right now', style: muStyle),
      for (final (month, items) in groupByMonth(list, (Ride r) => r.startTime)) ...[
        if (_rideFilter == 1) MonthHeader(month),
        for (final r in items)
          AppCard(onTap: () => showRideSheet(context, r), children: [
            TintIc(s.typeOf(s.vehicleById(r.vehicleId)).icon,
                r.isOverdue ? Tint.none : (s.typeOf(s.vehicleById(r.vehicleId)).isBike
                    ? Tint.bike
                    : Tint.scooter)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.vehicleById(r.vehicleId).code} · ${s.userById(r.userId).fullName}',
                      style: ts(12, w: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                      r.isOpen
                          ? '${s.stationById(r.startStationId).name} · due ${dmy(r.dueTime)} ${hm(r.dueTime)}'
                          : '${s.stationById(r.startStationId).name} · ${dmy(r.startTime)} · ${duration(r.usedTime)}',
                      style: muStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Pill(rideBadge(r).$1, kind: rideBadge(r).$2),
          ]),
      ],
    ];
  }

  // ---------------------------------------------------------------- Top-ups
  List<Widget> _topups(BuildContext context) {
    final s = AppStore.instance;
    return [
      Row(
        children: gapped([
          Expanded(
              child: Kpi(baht(s.topupsThisMonth), 'Topped up (month)',
                  tone: KpiTone.purple, icon: TablerIcons.wallet)),
          Expanded(
              child: Kpi(baht(s.revenueThisMonth), 'Ride revenue (month)',
                  tone: KpiTone.green, icon: TablerIcons.cash)),
        ], w: 8),
      ),
      for (final t in s.allTopups)
        AppCard(onTap: () => showTopupSheet(context, t), children: [
          TintIc(TablerIcons.wallet,
              t.status == TopupStatus.pending
                  ? Tint.few
                  : t.status == TopupStatus.paid
                      ? Tint.ready
                      : Tint.off),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${baht(t.amount)} · ${s.userById(t.userId).fullName}',
                    style: ts(12, w: FontWeight.w500)),
                Text('${dmy(t.createdAt)} · ${hm(t.createdAt)} · ${t.paymentMethod.toUpperCase()}',
                    style: muStyle),
              ],
            ),
          ),
          switch (t.status) {
            TopupStatus.pending => const Pill('Confirm', kind: PillKind.red),
            TopupStatus.paid => const Pill('Paid', kind: PillKind.gold),
            _ => Pill(t.status.name, kind: PillKind.gray),
          },
        ]),
    ];
  }

  // ---------------------------------------------------------------- Feedback
  List<Widget> _feedback(BuildContext context) {
    final s = AppStore.instance;
    final list = s.feedback;
    if (list.isEmpty) return [Text('No feedback yet', style: muStyle)];
    return [
      for (final f in list)
        AppCard(onTap: () => showFeedbackSheet(context, f), children: [
          TintIc(TablerIcons.messageReport, f.status == 'resolved' ? Tint.off : Tint.charging),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${f.topic.label} · ${s.userById(f.userId).firstName}',
                    style: ts(12, w: f.status == 'open' ? FontWeight.w700 : FontWeight.w500)),
                Text(f.message, style: muStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          switch (f.status) {
            'open' => const Pill('New', kind: PillKind.red),
            'read' => const Pill('Read', kind: PillKind.gold),
            _ => const Pill('Resolved', kind: PillKind.gray),
          },
        ]),
    ];
  }
}
