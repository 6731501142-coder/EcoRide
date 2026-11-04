// ฟอร์มเพิ่ม / แก้ไขสถานี (Create + Update) และปุ่มปิด/เปิดสถานี (Soft delete)
// station == null  → โหมดเพิ่มใหม่
// station != null  → โหมดแก้ไข
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/admin_models.dart';
import '../data/admin_store.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';

class StationFormScreen extends StatefulWidget {
  const StationFormScreen({super.key, this.station});
  final AdminStation? station;

  @override
  State<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends State<StationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _building, _desc, _qr, _lat, _lng;
  late int _capacity;
  late bool _active;

  bool get _isEdit => widget.station != null;

  @override
  void initState() {
    super.initState();
    final s = widget.station;
    _name = TextEditingController(text: s?.stationName ?? '');
    _building = TextEditingController(text: s?.buildingName ?? '');
    _desc = TextEditingController(text: s?.description ?? '');
    _qr = TextEditingController(text: s?.qrCode ?? '');
    _lat = TextEditingController(text: s?.latitude?.toString() ?? '');
    _lng = TextEditingController(text: s?.longitude?.toString() ?? '');
    _capacity = s?.capacity ?? 6;
    _active = s?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _building, _desc, _qr, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _number(String? v) {
    if (v == null || v.trim().isEmpty) return null; // ไม่บังคับกรอก
    return double.tryParse(v.trim()) == null ? 'Must be a number' : null;
  }

  String? _clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// ปุ่ม Save: ตรวจฟอร์ม → ส่งให้ store → ถ้าผ่านปิดหน้า, ไม่ผ่านแสดง error
  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final draft = AdminStation(
      stationId: widget.station?.stationId ?? 0, // 0 = ให้ store สร้าง id ใหม่
      stationName: _name.text.trim(),
      buildingName: _building.text.trim(),
      description: _clean(_desc),
      qrCode: _clean(_qr),
      capacity: _capacity,
      latitude: double.tryParse(_lat.text.trim()),
      longitude: double.tryParse(_lng.text.trim()),
      status: _active ? StationStatus.active : StationStatus.inactive,
    );
    final store = AdminStore.instance;
    final err = _isEdit ? store.updateStation(draft) : store.addStation(draft);
    if (err != null) {
      toast(context, err, error: true);
      return;
    }
    toast(context, _isEdit ? 'Station updated' : 'Station added');
    Navigator.of(context).pop();
  }

  /// ปุ่ม Deactivate / Reactivate – ไม่ลบจริง เพราะ FK RESTRICT กับประวัติการยืม
  Future<void> _toggleActive() async {
    final s = widget.station!;
    final store = AdminStore.instance;
    if (s.isActive) {
      final ok = await confirmDialog(
        context,
        title: 'Deactivate ${s.stationName}?',
        message: 'Users will no longer see or return vehicles here. '
            'History is kept and you can reactivate it later.',
        ok: 'Deactivate',
      );
      if (!ok) return;
      store.deactivateStation(s.stationId);
    } else {
      store.reactivateStation(s.stationId);
    }
    if (!mounted) return;
    toast(context, s.isActive ? 'Station reactivated' : 'Station deactivated');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Ui.init(context);
    final s = widget.station;
    final a = s == null ? null : AdminStore.instance.availability(s);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: _isEdit ? 'Edit station' : 'Add station',
              leading: const BackIcon(),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(12.px, 4.px, 12.px, 12.px),
                  children: gapped([
                    if (a != null)
                      Row(
                        children: gapped([
                          Expanded(child: Kpi('${a.availableVehicles}', 'Ready')),
                          Expanded(child: Kpi('${a.occupiedSlots}/${s!.capacity}', 'Docks used')),
                          Expanded(child: Kpi('${a.freeSlots}', 'Free')),
                        ], w: 7),
                      ),
                    AdminField(
                        key: const Key('f_station_name'),
                        label: 'Station name',
                        hint: 'e.g. Library Station',
                        controller: _name,
                        validator: _required),
                    AdminField(
                        key: const Key('f_building'),
                        label: 'Building',
                        hint: 'e.g. Central Library',
                        controller: _building,
                        validator: _required),
                    AdminField(
                        label: 'Description (optional)',
                        hint: 'e.g. In front of the main entrance',
                        controller: _desc),
                    AdminField(
                        label: 'Station QR code',
                        hint: 'e.g. STN-LIB',
                        controller: _qr),
                    _CapacityStepper(
                      value: _capacity,
                      onChanged: (v) => setState(() => _capacity = v),
                    ),
                    Row(
                      children: gapped([
                        Expanded(
                          child: AdminField(
                              label: 'Latitude',
                              hint: '13.7563',
                              controller: _lat,
                              number: true,
                              decimal: true,
                              validator: _number),
                        ),
                        Expanded(
                          child: AdminField(
                              label: 'Longitude',
                              hint: '100.5018',
                              controller: _lng,
                              number: true,
                              decimal: true,
                              validator: _number),
                        ),
                      ], w: 7),
                    ),
                    if (!_isEdit)
                      _ActiveSwitch(
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                  ], h: 9),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.px, 0, 12.px, 8.px),
              child: Column(
                children: gapped([
                  Btn(_isEdit ? 'Save changes' : 'Add station',
                      key: const Key('btn_save_station'),
                      icon: TablerIcons.check,
                      onTap: _save),
                  if (_isEdit)
                    Btn(s!.isActive ? 'Deactivate station' : 'Reactivate station',
                        key: const Key('btn_toggle_station'),
                        icon: s!.isActive ? TablerIcons.ban : TablerIcons.refresh,
                        kind: BtnKind.outlined,
                        onTap: _toggleActive),
                ], h: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ปุ่ม − / + ปรับจำนวนช่องจอด (capacity ต้อง >= 1)
class _CapacityStepper extends StatelessWidget {
  const _CapacityStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  Widget _btn(IconData icon, VoidCallback? onTap, Key key) => GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          width: 28.px,
          height: 28.px,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null ? C.grayPillBg : C.redBg,
          ),
          child: Icon(icon, size: 13.px, color: onTap == null ? C.hint : C.red),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.px, vertical: 6.px),
      decoration: BoxDecoration(color: C.inputBg, borderRadius: BorderRadius.circular(12.px)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Capacity (docks)', style: ts(11, color: C.muted)),
                Text('$value', key: const Key('capacity_value'), style: ts(15, w: FontWeight.w500)),
              ],
            ),
          ),
          _btn(TablerIcons.minus, value > 1 ? () => onChanged(value - 1) : null,
              const Key('btn_cap_minus')),
          SizedBox(width: 8.px),
          _btn(TablerIcons.plus, value < 50 ? () => onChanged(value + 1) : null,
              const Key('btn_cap_plus')),
        ],
      ),
    );
  }
}

class _ActiveSwitch extends StatelessWidget {
  const _ActiveSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.px, vertical: 2.px),
      decoration: BoxDecoration(color: C.inputBg, borderRadius: BorderRadius.circular(12.px)),
      child: Row(
        children: [
          Expanded(child: Text('Open for users now', style: ts(11, color: C.muted))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: C.red,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
          ),
        ],
      ),
    );
  }
}
