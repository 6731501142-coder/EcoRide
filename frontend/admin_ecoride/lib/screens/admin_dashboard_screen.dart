// Admin หน้า 1) Dashboard – ภาพรวมระบบ
// แสดง: รถที่ถูกยืม, รถที่ต้องชาร์จ, รถซ่อม, สถานะทุกสถานี
// ข้อมูลมาจาก AdminStore.summary (= VIEW v_dashboard_summary)
// และ AdminStore.availability() (= VIEW v_station_availability)
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/admin_models.dart';
import '../data/admin_store.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/basic.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, required this.onOpenTab, this.onLogout});

  /// เปลี่ยนแท็บของ AdminShell (1 = Stations, 2 = Vehicles)
  final ValueChanged<int> onOpenTab;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;
    // ListenableBuilder = วาดหน้าใหม่ทุกครั้งที่ store เรียก notifyListeners()
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final sum = store.summary;
        return Column(
          children: [
            AdminHeader(
              subtitle: 'Admin dashboard',
              title: 'EcoRide overview',
              trailing: GestureDetector(
                key: const Key('btn_logout'),
                onTap: onLogout,
                child: Icon(TablerIcons.logout, size: 18.px, color: Colors.white),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(12.px, 8.px, 12.px, 12.px),
                children: gapped([
                  // ---- KPI แถวบน: ตัวเลขสำคัญ 3 ตัว
                  Row(
                    children: gapped([
                      Expanded(child: Kpi('${sum.borrowedVehicles}', 'Borrowed')),
                      Expanded(child: Kpi('${sum.lowBatteryVehicles}', 'Need charge')),
                      Expanded(child: Kpi('${sum.maintenanceVehicles}', 'Repair')),
                    ], w: 7),
                  ),
                  _FleetCard(sum),
                  SectionTitle('Stations',
                      action: 'Manage', onAction: () => onOpenTab(1)),
                  for (final s in store.stations) _StationStatusTile(s),
                  SizedBox(height: 2.px),
                  Btn('Manage stations',
                      icon: TablerIcons.mapPin, onTap: () => onOpenTab(1)),
                  Btn('Manage vehicles',
                      icon: TablerIcons.bike,
                      kind: BtnKind.outlined,
                      onTap: () => onOpenTab(2)),
                ], h: 8),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// การ์ด "สถานะรถทั้งหมด" – แถบสีแบ่งสัดส่วน + คำอธิบาย
class _FleetCard extends StatelessWidget {
  const _FleetCard(this.sum);
  final DashboardSummary sum;

  @override
  Widget build(BuildContext context) {
    final parts = <(String, int, Color)>[
      ('Available', sum.availableVehicles, C.gold),
      ('Borrowed', sum.borrowedVehicles, C.red),
      ('Maintenance', sum.maintenanceVehicles, C.goldIcon),
      ('Unavailable', sum.unavailableVehicles, C.chipLine),
    ];
    final total = sum.totalVehicles == 0 ? 1 : sum.totalVehicles;
    return Container(
      padding: EdgeInsets.all(10.px),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: C.line, width: 1.px),
        borderRadius: BorderRadius.circular(16.px),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Fleet status', style: ttStyle)),
              Text('${sum.totalVehicles} vehicles', style: muStyle),
            ],
          ),
          SizedBox(height: 7.px),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.px),
            child: SizedBox(
              height: 8.px,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in parts)
                    if (p.$2 > 0)
                      Expanded(flex: (p.$2 * 1000) ~/ total, child: ColoredBox(color: p.$3)),
                ],
              ),
            ),
          ),
          SizedBox(height: 7.px),
          Wrap(
            spacing: 10.px,
            runSpacing: 4.px,
            children: [
              for (final p in parts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7.px,
                      height: 7.px,
                      decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 3.px),
                    Text('${p.$1} ${p.$2}', style: muStyle),
                  ],
                ),
            ],
          ),
          SizedBox(height: 4.px),
          Text('${sum.activeStations} of ${sum.totalStations} stations active',
              style: muStyle),
        ],
      ),
    );
  }
}

/// แถวสถานะสถานี: ช่องจอดที่ใช้ / ทั้งหมด
class _StationStatusTile extends StatelessWidget {
  const _StationStatusTile(this.s);
  final AdminStation s;

  @override
  Widget build(BuildContext context) {
    final a = AdminStore.instance.availability(s);
    final full = a.freeSlots <= 0;
    final pct = (a.occupiedSlots * 100) ~/ s.capacity;
    final (String badge, PillKind kind) = !s.isActive
        ? ('Inactive', PillKind.gray)
        : full
            ? ('Full', PillKind.red)
            : ('${a.freeSlots} free', PillKind.gold);
    return AppCard(
      children: [
        Ic(TablerIcons.building, red: !s.isActive || full),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.stationName, style: ttStyle),
              Text('${_plural(a.availableBikes, 'bike')} · ${_plural(a.availableScooters, 'scooter')} ready',
                  style: muStyle),
              SizedBox(height: 4.px),
              Bar(pct, red: full),
              SizedBox(height: 2.px),
              Text('${a.occupiedSlots} / ${s.capacity} docks used', style: ts(10, color: C.hint)),
            ],
          ),
        ),
        Pill(badge, kind: kind),
      ],
    );
  }
}

/// เติม s ให้คำนามเมื่อจำนวนไม่ใช่ 1 เช่น 1 bike, 2 bikes, 0 scooters
String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
