// โครงแอป Admin (5 แท็บ) + หน้า Overview
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import 'admin_ui.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';
import '../widgets/form.dart';
import '../widgets/station_pic.dart';
import '../screens/auth_screens.dart';
import 'reports_screen.dart';
import 'sheets.dart';
import 'stations_screen.dart';
import 'users_screen.dart';
import 'vehicles_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  int _reportsTab = 0; // เปิดแท็บย่อยของ Reports จากหน้า Overview ได้

  void _openReports(int sub) => setState(() {
        _tab = 3;
        _reportsTab = sub;
      });

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            OverviewTab(onOpenReports: _openReports, onOpenTab: (i) => setState(() => _tab = i)),
            const StationsTab(),
            const VehiclesTab(),
            ReportsTab(key: ValueKey(_reportsTab), initial: _reportsTab),
            const UsersTab(),
          ],
        ),
        bottomNavigationBar: AdminNavBar(
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
          // จุดแดง = เรื่องที่รอแอดมิน (issue ที่ยังไม่ปิด + top-up รอยืนยัน + feedback ยังไม่อ่าน)
          badges: {
            3: s.openReports.length + s.pendingTopups.length + s.unreadFeedback,
          },
        ),
      ),
    );
  }
}

// ======================================================================= Overview
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.onOpenReports, required this.onOpenTab});
  final ValueChanged<int> onOpenReports; // 0 Issues, 1 Rides, 2 Top-ups, 3 Feedback
  final ValueChanged<int> onOpenTab;

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Log out?', message: 'You will need to log in again.', ok: 'Log out');
    if (!ok || !context.mounted) return;
    // ไปหน้า login ก่อน แล้วค่อยล้างข้อมูลแอดมิน (กันหน้าเก่าวาดใหม่ตอน me = null)
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    AppStore.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    final me = s.me!;
    final vehicles = s.vehicles;
    final ready = vehicles.where(s.canBorrowVehicle).length;
    final charging = vehicles.where(s.isCharging).length;
    final repair = vehicles.where((v) => v.status == VehicleStatus.maintenance).length;

    // รายการ "ต้องจัดการ" เรียงตามความด่วน
    final urgent = s.urgentOpen;
    final overdue = s.overdueRides;
    final pending = s.pendingTopups;
    final otherIssues = s.openReports.where((r) => !r.isUrgent).toList();
    final allClear = urgent.isEmpty && overdue.isEmpty && pending.isEmpty && otherIssues.isEmpty;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        RedHeader(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EcoRide Admin', style: ts(12, color: const Color(0xFFFFE6E3))),
                    Text('Hello, ${me.firstName}',
                        style: ts(20, w: FontWeight.w600, color: Colors.white)),
                    Text('${dmy(DateTime.now())} · ${hm(DateTime.now())}',
                        style: ts(11, color: const Color(0xFFFFE6E3))),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Log out',
                onPressed: () => _logout(context),
                icon: Icon(TablerIcons.logout, size: 20.px, color: Colors.white),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(14.px, 12.px, 14.px, 16.px),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: gapped([
              // แถว 1: สิ่งที่เกิดขึ้นตอนนี้
              Row(
                children: gapped([
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onOpenReports(1),
                      child: Kpi('${s.openRides.length}', 'Riding now',
                          tone: KpiTone.blue, icon: TablerIcons.bike),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onOpenReports(1),
                      child: Kpi('${overdue.length}', 'Overdue',
                          tone: KpiTone.rose, icon: TablerIcons.alarm),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onOpenReports(0),
                      child: Kpi('${s.openReports.length}', 'Open issues',
                          tone: KpiTone.gold, icon: TablerIcons.alertTriangle),
                    ),
                  ),
                ], w: 8),
              ),
              // แถว 2: เงิน + รถ
              Row(
                children: gapped([
                  Expanded(
                      child: Kpi(baht(s.revenueThisMonth), 'Revenue (month)',
                          tone: KpiTone.green, icon: TablerIcons.cash)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onOpenTab(2),
                      child: Kpi('$ready', 'Ready vehicles',
                          tone: KpiTone.purple, icon: TablerIcons.bolt),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onOpenTab(2),
                      child: Kpi('$charging · $repair', 'Charging · Repair',
                          tone: KpiTone.gold, icon: TablerIcons.plugConnected),
                    ),
                  ),
                ], w: 8),
              ),

              Text('Needs attention', style: ts(13, w: FontWeight.w600)),
              if (allClear)
                AppCard(children: [
                  const TintIc(TablerIcons.circleCheck, Tint.ready),
                  Expanded(child: Text('All clear – nothing waiting', style: ts(12))),
                ]),
              for (final r in urgent)
                _AttentionCard(
                  icon: TablerIcons.urgent,
                  tint: Tint.none,
                  title: 'Need help · ${s.vehicleById(r.vehicleId).code}',
                  sub: '${s.userById(r.userId).firstName} · '
                      '${(r.details ?? '').replaceFirst('[URGENT] ', '')}',
                  badge: reportBadge(r.status),
                  onTap: () => showReportSheet(context, r),
                ),
              for (final r in overdue)
                _AttentionCard(
                  icon: TablerIcons.alarm,
                  tint: Tint.none,
                  title: 'Overdue · ${s.vehicleById(r.vehicleId).code}',
                  sub: '${s.userById(r.userId).fullName} · due ${dmy(r.dueTime)} ${hm(r.dueTime)}',
                  badge: ('Overdue', PillKind.solid),
                  onTap: () => showRideSheet(context, r),
                ),
              for (final t in pending)
                _AttentionCard(
                  icon: TablerIcons.wallet,
                  tint: Tint.ready,
                  title: 'Top-up ${baht(t.amount)} waiting',
                  sub: '${s.userById(t.userId).fullName} · ${ago(t.createdAt)}',
                  badge: ('Confirm', PillKind.gold),
                  onTap: () => showTopupSheet(context, t),
                ),
              for (final r in otherIssues)
                _AttentionCard(
                  icon: TablerIcons.alertTriangle,
                  tint: Tint.few,
                  title: '${r.category.label} · ${s.vehicleById(r.vehicleId).code}',
                  sub: r.details ?? '',
                  badge: reportBadge(r.status),
                  onTap: () => showReportSheet(context, r),
                ),
              if (s.unreadFeedback > 0)
                _AttentionCard(
                  icon: TablerIcons.messageReport,
                  tint: Tint.charging,
                  title: '${s.unreadFeedback} new feedback',
                  sub: 'From users of the EcoRide app',
                  badge: ('Read', PillKind.gold),
                  onTap: () => onOpenReports(3),
                ),

              SizedBox(height: 2.px),
              Text('Stations', style: ts(13, w: FontWeight.w600)),
              for (final st in s.allStations) _StationMini(st, onTap: () => onOpenTab(1)),
            ], h: 9),
          ),
        ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.sub,
    required this.badge,
    required this.onTap,
  });
  final IconData icon;
  final Tint tint;
  final String title;
  final String sub;
  final (String, PillKind) badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(onTap: onTap, children: [
      TintIc(icon, tint),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ts(12, w: FontWeight.w500)),
            Text(sub, style: muStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      Pill(badge.$1, kind: badge.$2),
    ]);
  }
}

/// สถานีแบบย่อ: ชื่อ + ช่องจอดที่ใช้ + รถพร้อม
class _StationMini extends StatelessWidget {
  const _StationMini(this.st, {required this.onTap});
  final Station st;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = AppStore.instance.availability(st);
    final used = st.totalDocks - a.freeDocks;
    return AppCard(onTap: onTap, children: [
      StationPic(st,
          !st.isActive ? Tint.off : (a.ready == 0 || a.full ? Tint.none : Tint.ready)),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(st.name, style: ts(12, w: FontWeight.w500))),
              Text('$used/${st.totalDocks} docks', style: ts(10, color: C.chipText)),
            ]),
            SizedBox(height: 4.px),
            Bar((used / st.totalDocks * 100).round(), red: a.full),
            SizedBox(height: 3.px),
            Text(st.isActive ? '${a.ready} ready to ride' : 'Closed', style: muStyle),
          ],
        ),
      ),
    ]);
  }
}
