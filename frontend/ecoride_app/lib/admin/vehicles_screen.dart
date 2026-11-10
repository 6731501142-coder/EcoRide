// แท็บ Vehicles: รถทุกคัน + แบตสด, กรองตามประเภท/สถานะ, ค้นหารหัส, ส่งซ่อม, เพิ่มรถใหม่
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import 'admin_ui.dart';
import '../widgets/basic.dart';
import '../widgets/form.dart';
import 'sheets.dart';

class VehiclesTab extends StatefulWidget {
  const VehiclesTab({super.key});

  @override
  State<VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<VehiclesTab> {
  static const _filters = ['All', 'E-bikes', 'Scooters', 'In use', 'Charging', 'Repair'];
  int _filter = 0;
  String _q = '';

  bool _match(Vehicle v) {
    final s = AppStore.instance;
    if (_q.isNotEmpty && !v.code.toLowerCase().contains(_q.toLowerCase())) return false;
    return switch (_filter) {
      1 => s.typeOf(v).isBike,
      2 => !s.typeOf(v).isBike,
      3 => v.status == VehicleStatus.inUse,
      4 => s.isCharging(v),
      5 => v.status == VehicleStatus.maintenance,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list = s.vehicles.where(_match).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final all = s.vehicles;
        return Column(
          children: [
            TabHeader('Vehicles',
                subtitle: '${all.length} total · '
                    '${all.where((v) => v.status == VehicleStatus.inUse).length} in use · '
                    '${all.where((v) => v.status == VehicleStatus.maintenance).length} in repair',
                trailing:
                    AddCircle(tooltip: 'Add vehicle', onTap: () => _addVehicle(context))),
            Padding(
              padding: EdgeInsets.fromLTRB(14.px, 2.px, 14.px, 6.px),
              child: TextField(
                onChanged: (t) => setState(() => _q = t.trim()),
                style: ts(12),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: C.inputBg,
                  hintText: 'Search code, e.g. EB-012',
                  hintStyle: ts(12, color: C.muted),
                  prefixIcon: Icon(TablerIcons.search, size: 14.px, color: C.chipText),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.px, vertical: 10.px),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.px),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chips(_filters,
                    selected: _filter, onSelect: (i) => setState(() => _filter = i)),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14.px, 8.px, 14.px, 16.px),
                children: gapped([
                  if (list.isEmpty) Text('No vehicles match', style: muStyle),
                  for (final v in list) _VehicleRow(v),
                ], h: 8),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addVehicle(BuildContext context) async {
    final s = AppStore.instance;
    final number = TextEditingController();
    var type = s.types.first;
    var station = s.allStations.first;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: C.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.px)),
          title: Text('Add vehicle', style: ts(14, w: FontWeight.w600)),
          content: SizedBox(
            width: 260.px,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: gapped([
                Text('Type', style: ts(11, color: C.chipText)),
                Chips([for (final t in s.types) t.name],
                    selected: s.types.indexOf(type),
                    onSelect: (i) => setD(() => type = s.types[i])),
                Text('Number (code will be ${type.codePrefix}-xxx)',
                    style: ts(11, color: C.chipText)),
                TextField(
                  controller: number,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: ts(12),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: C.inputBg,
                    prefixText: '${type.codePrefix}-',
                    hintText: '022',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.px), borderSide: BorderSide.none),
                  ),
                ),
                Text('Park at', style: ts(11, color: C.chipText)),
                Chips([for (final st in s.allStations) st.name],
                    selected: s.allStations.indexOf(station),
                    onSelect: (i) => setD(() => station = s.allStations[i])),
              ], h: 8),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: ts(11, color: C.chipText))),
            TextButton(
              onPressed: () {
                final err = s.addVehicle(type: type, number: number.text, station: station);
                if (err != null) return toast(context, err, error: true);
                Navigator.pop(ctx);
                toast(context, 'Vehicle added to ${station.name}');
              },
              child: Text('Add', style: ts(11, w: FontWeight.w600, color: C.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow(this.v);
  final Vehicle v;

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    final pct = s.liveBattery(v);
    final ride = s.openRideOf(v);
    final where = v.currentStationId != null
        ? s.stationById(v.currentStationId!).name
        : ride != null
            ? 'Riding · ${s.userById(ride.userId).firstName}'
            : '—';
    final (badge, kind) = vehicleBadge(v);
    return GestureDetector(
      onTap: () => showVehicleSheet(context, v),
      child: Container(
        padding: EdgeInsets.fromLTRB(10.px, 8.px, 8.px, 8.px),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: C.line, width: 1.px),
          borderRadius: BorderRadius.circular(16.px),
        ),
        child: Row(
          children: [
            TintIc(s.typeOf(v).icon, vehicleTint(v)),
            SizedBox(width: 8.px),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(v.code, style: ts(12, w: FontWeight.w500)),
                    SizedBox(width: 6.px),
                    Expanded(
                      child: Text(where,
                          style: muStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Pill(badge, kind: kind),
                  ]),
                  SizedBox(height: 5.px),
                  Row(children: [
                    Expanded(child: Bar(pct, red: pct < AppStore.minBattery)),
                    SizedBox(width: 6.px),
                    if (s.isCharging(v))
                      Icon(TablerIcons.plugConnected, size: 11.px, color: Tint.charging.fg),
                    Text(' $pct%', style: ts(10, w: FontWeight.w500)),
                  ]),
                ],
              ),
            ),
            SizedBox(width: 4.px),
            Icon(TablerIcons.chevronRight, size: 14.px, color: C.chipText),
          ],
        ),
      ),
    );
  }
}
