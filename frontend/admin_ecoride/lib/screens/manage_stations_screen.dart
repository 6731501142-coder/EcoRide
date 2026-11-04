// Admin หน้า 2) Manage Stations – รายการสถานี (Read) + ปุ่มไปเพิ่ม/แก้ไข/ปิดสถานี
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/admin_models.dart';
import '../data/admin_store.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/basic.dart';
import 'station_form_screen.dart';

class ManageStationsScreen extends StatefulWidget {
  const ManageStationsScreen({super.key});

  @override
  State<ManageStationsScreen> createState() => _ManageStationsScreenState();
}

class _ManageStationsScreenState extends State<ManageStationsScreen> {
  String _query = ''; // คำค้นหา
  int _filter = 0; // 0 = All, 1 = Active, 2 = Inactive

  List<AdminStation> _visible(List<AdminStation> all) {
    final q = _query.toLowerCase();
    return all.where((s) {
      final matchText = s.stationName.toLowerCase().contains(q) ||
          s.buildingName.toLowerCase().contains(q);
      final matchFilter = _filter == 0 ||
          (_filter == 1 && s.isActive) ||
          (_filter == 2 && !s.isActive);
      return matchText && matchFilter;
    }).toList();
  }

  void _openForm([AdminStation? s]) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StationFormScreen(station: s)),
      );

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = _visible(store.stations);
        return Column(
          children: [
            AdminHeader(
              subtitle: 'Admin',
              title: 'Manage stations',
              trailing: GestureDetector(
                key: const Key('btn_add_station_top'),
                onTap: _openForm,
                child: Icon(TablerIcons.circlePlus, size: 20.px, color: Colors.white),
              ),
              child: AdminSearch(
                hint: 'Search station or building',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.px, 8.px, 12.px, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Chips(
                      const ['All', 'Active', 'Inactive'],
                      selected: _filter,
                      onSelect: (i) => setState(() => _filter = i),
                    ),
                  ),
                  Text('${list.length} stations', style: muStyle),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text('No stations found', style: muStyle))
                  : ListView(
                      padding: EdgeInsets.fromLTRB(12.px, 8.px, 12.px, 8.px),
                      children: gapped([
                        for (final s in list)
                          _StationRow(s, onTap: () => _openForm(s)),
                      ], h: 7),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.px, 0, 12.px, 8.px),
              child: Btn('Add station',
                  key: const Key('btn_add_station'),
                  icon: TablerIcons.plus,
                  onTap: _openForm),
            ),
          ],
        );
      },
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow(this.s, {required this.onTap});
  final AdminStation s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = AdminStore.instance.availability(s);
    return AppCard(
      onTap: onTap,
      children: [
        Ic(TablerIcons.building, red: !s.isActive),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.stationName, style: ttStyle),
              Text('${s.buildingName} · ${s.qrCode ?? 'no QR'}', style: muStyle),
              Text('Docks ${a.occupiedSlots}/${s.capacity} · ${a.freeSlots} free',
                  style: ts(10, color: C.hint)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Pill(s.isActive ? 'Active' : 'Inactive',
                kind: s.isActive ? PillKind.gold : PillKind.gray),
            SizedBox(height: 4.px),
            Icon(TablerIcons.pencil, size: 12.px, color: C.hint),
          ],
        ),
      ],
    );
  }
}
