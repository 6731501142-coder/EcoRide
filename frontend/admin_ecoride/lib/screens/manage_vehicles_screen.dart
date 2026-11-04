// Admin หน้า 3) Manage Vehicles – รายการจักรยาน/สกู๊ตเตอร์ + เปลี่ยนสถานะ พร้อมใช้ / ส่งซ่อม
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/admin_models.dart';
import '../data/admin_store.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/basic.dart';
import 'vehicle_form_screen.dart';

class ManageVehiclesScreen extends StatefulWidget {
  const ManageVehiclesScreen({super.key});

  @override
  State<ManageVehiclesScreen> createState() => _ManageVehiclesScreenState();
}

class _ManageVehiclesScreenState extends State<ManageVehiclesScreen> {
  String _query = '';
  int _type = 0; // 0 All, 1 E-bikes, 2 Scooters
  int _status = 0; // 0 All, 1.. = VehicleStatus.values[i-1]

  static const _statusLabels = ['All', 'Available', 'Borrowed', 'Maintenance', 'Unavailable'];

  List<AdminVehicle> _visible(List<AdminVehicle> all) {
    final q = _query.toLowerCase();
    return all.where((v) {
      final st = AdminStore.instance.stationById(v.stationId);
      final text = v.vehicleCode.toLowerCase().contains(q) ||
          (st?.stationName.toLowerCase().contains(q) ?? false);
      final type = _type == 0 ||
          (_type == 1 && v.vehicleType == VehicleType.eBike) ||
          (_type == 2 && v.vehicleType == VehicleType.eScooter);
      final status = _status == 0 || v.status == VehicleStatus.values[_status - 1];
      return text && type && status;
    }).toList();
  }

  void _openForm([AdminVehicle? v]) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VehicleFormScreen(vehicle: v)),
      );

  /// กดที่รถ 1 คัน → เมนูด่วนด้านล่าง
  void _openActions(AdminVehicle v) {
    final store = AdminStore.instance;
    void run(String? err, String okMsg) {
      Navigator.pop(context); // ปิด bottom sheet
      toast(context, err ?? okMsg, error: err != null);
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.px)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.px, 12.px, 12.px, 8.px),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: gapped([
              Row(
                children: gapped([
                  Ic(v.vehicleType.icon),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.vehicleCode, style: ttStyle),
                        Text('${v.vehicleType.label} · battery ${v.batteryLevel}%',
                            style: muStyle),
                      ],
                    ),
                  ),
                  VehicleStatusPill(v.status),
                ], w: 8),
              ),
              if (v.status == VehicleStatus.borrowed)
                Text('This vehicle is on a ride. Status changes after the user returns it.',
                    style: muStyle),
              if (v.status != VehicleStatus.borrowed) ...[
                if (v.status != VehicleStatus.available)
                  Btn('Mark as available',
                      key: const Key('act_available'),
                      icon: TablerIcons.circleCheck,
                      onTap: () => run(store.setVehicleStatus(v, VehicleStatus.available),
                          '${v.vehicleCode} is available')),
                if (v.status != VehicleStatus.maintenance)
                  Btn('Send to maintenance',
                      key: const Key('act_maintenance'),
                      icon: TablerIcons.tool,
                      kind: BtnKind.gold,
                      onTap: () => run(store.setVehicleStatus(v, VehicleStatus.maintenance),
                          '${v.vehicleCode} sent to maintenance')),
              ],
              Btn('Edit details',
                  key: const Key('act_edit'),
                  icon: TablerIcons.pencil,
                  kind: BtnKind.outlined, onTap: () {
                Navigator.pop(ctx);
                _openForm(v);
              }),
              if (v.status != VehicleStatus.borrowed &&
                  v.status != VehicleStatus.unavailable)
                GestureDetector(
                  key: const Key('act_remove'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await confirmDialog(context,
                        title: 'Remove ${v.vehicleCode}?',
                        message: 'The vehicle is marked Unavailable and hidden from users. '
                            'Borrowing history is kept.',
                        ok: 'Remove');
                    if (!ok || !mounted) return;
                    final err = store.retireVehicle(v);
                    if (!mounted) return;
                    toast(context, err ?? '${v.vehicleCode} removed', error: err != null);
                  },
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(4.px),
                      child: Text('Remove vehicle', style: ts(11, color: C.redText)),
                    ),
                  ),
                ),
            ], h: 7),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = _visible(store.vehicles);
        return Column(
          children: [
            AdminHeader(
              subtitle: 'Admin',
              title: 'Manage vehicles',
              trailing: GestureDetector(
                key: const Key('btn_add_vehicle_top'),
                onTap: _openForm,
                child: Icon(TablerIcons.circlePlus, size: 20.px, color: Colors.white),
              ),
              child: AdminSearch(
                hint: 'Search code or station',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.px, 8.px, 12.px, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: gapped([
                  Chips(const ['All types', 'E-bikes', 'Scooters'],
                      selected: _type, onSelect: (i) => setState(() => _type = i)),
                  Chips(_statusLabels,
                      selected: _status, onSelect: (i) => setState(() => _status = i)),
                ], h: 5),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text('No vehicles found', style: muStyle))
                  : ListView(
                      padding: EdgeInsets.fromLTRB(12.px, 8.px, 12.px, 8.px),
                      children: gapped([
                        for (final v in list) _VehicleRow(v, onTap: () => _openActions(v)),
                      ], h: 7),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.px, 0, 12.px, 8.px),
              child: Btn('Add vehicle',
                  key: const Key('btn_add_vehicle'), icon: TablerIcons.plus, onTap: _openForm),
            ),
          ],
        );
      },
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow(this.v, {required this.onTap});
  final AdminVehicle v;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = AdminStore.instance.stationById(v.stationId);
    final where = v.status == VehicleStatus.borrowed ? 'On a ride' : (st?.stationName ?? 'No station');
    final warn = v.lowBattery || v.status == VehicleStatus.maintenance;
    return AppCard(
      onTap: onTap,
      children: [
        Ic(v.vehicleType.icon, red: warn),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(v.vehicleCode, style: ttStyle),
                  const Spacer(),
                  Text('${v.batteryLevel}%',
                      style: ts(11, color: v.lowBattery ? C.redText : C.goldText)),
                ],
              ),
              SizedBox(height: 3.px),
              Bar(v.batteryLevel, red: v.lowBattery),
              SizedBox(height: 3.px),
              Text('${v.vehicleType.label} · $where', style: muStyle),
            ],
          ),
        ),
        VehicleStatusPill(v.status),
      ],
    );
  }
}
