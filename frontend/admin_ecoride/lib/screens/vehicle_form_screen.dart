// ฟอร์มเพิ่ม / แก้ไขรถ (Create + Update)
// vehicle == null → เพิ่มรถใหม่ , vehicle != null → แก้ไข
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/admin_models.dart';
import '../data/admin_store.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});
  final AdminVehicle? vehicle;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code, _qr;
  late VehicleType _type;
  late int? _stationId;
  late double _battery;
  late VehicleStatus _status;

  bool get _isEdit => widget.vehicle != null;
  bool get _isBorrowed => widget.vehicle?.status == VehicleStatus.borrowed;

  // สถานะที่ admin ตั้งเองได้ ("borrowed" ระบบตั้งให้ตอนผู้ใช้ยืมเท่านั้น)
  static const _editable = [
    VehicleStatus.available,
    VehicleStatus.maintenance,
    VehicleStatus.unavailable,
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _code = TextEditingController(text: v?.vehicleCode ?? '');
    _qr = TextEditingController(text: v?.qrCode ?? '');
    _type = v?.vehicleType ?? VehicleType.eBike;
    _stationId = v == null ? _firstFreeStation() : v.stationId;
    _battery = (v?.batteryLevel ?? 100).toDouble();
    _status = v?.status ?? VehicleStatus.available;
    // ตอนเพิ่มรถใหม่: พิมพ์รหัสรถแล้วเติม QR ให้อัตโนมัติ (QR-รหัสรถ)
    _code.addListener(() {
      if (!_isEdit) _qr.text = _code.text.isEmpty ? '' : 'QR-${_code.text.trim()}';
    });
  }

  /// หาสถานีแรกที่เปิดอยู่และยังมีช่องจอดว่าง (ใช้ตอนเพิ่มรถใหม่)
  int? _firstFreeStation() {
    final store = AdminStore.instance;
    for (final s in store.stations) {
      if (s.isActive && store.availability(s).freeSlots > 0) return s.stationId;
    }
    return null; // ทุกสถานีเต็ม → ไม่เลือกให้
  }
  
  @override
  void dispose() {
    _code.dispose();
    _qr.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final draft = AdminVehicle(
      vehicleId: widget.vehicle?.vehicleId ?? 0,
      vehicleCode: _code.text.trim().toUpperCase(),
      qrCode: _qr.text.trim(),
      vehicleType: _type,
      stationId: _isBorrowed ? null : _stationId,
      batteryLevel: _battery.round(),
      status: _status,
    );
    final store = AdminStore.instance;
    final err = _isEdit ? store.updateVehicle(draft) : store.addVehicle(draft);
    if (err != null) {
      toast(context, err, error: true);
      return;
    }
    toast(context, _isEdit ? '${draft.vehicleCode} updated' : '${draft.vehicleCode} added');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Ui.init(context);
    final store = AdminStore.instance;
    // เลือกได้เฉพาะสถานีที่เปิดอยู่ (หรือสถานีเดิมของรถคันนี้)
    final stations = store.stations
        .where((s) => s.isActive || s.stationId == widget.vehicle?.stationId)
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: _isEdit ? 'Edit vehicle' : 'Add vehicle', leading: const BackIcon()),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(12.px, 4.px, 12.px, 12.px),
                  children: gapped([
                    // ---- รูปรถตามประเภท (เหมือนหน้า Vehicle details ฝั่ง User)
                    Container(
                      height: 80.px,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: C.goldBg,
                        borderRadius: BorderRadius.circular(16.px),
                      ),
                      child: Icon(_type.icon, size: 42.px, color: C.red),
                    ),
                    Text('Vehicle type', style: ts(11, color: C.muted)),
                    Chips(const ['E-bike', 'E-scooter'],
                        selected: _type.index,
                        onSelect: (i) => setState(() => _type = VehicleType.values[i])),
                    AdminField(
                      key: const Key('f_vehicle_code'),
                      label: 'Vehicle code',
                      hint: 'e.g. EB-007',
                      controller: _code,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    AdminField(
                      label: 'QR code on vehicle',
                      hint: 'e.g. QR-EB-007',
                      controller: _qr,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    // ---- สถานีที่จอด
                    Text('Parked at station', style: ts(11, color: C.muted)),
                    if (_isBorrowed)
                      Text('On a ride – station is set when the user returns it',
                          style: muStyle)
                    else
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.px),
                        decoration: BoxDecoration(
                            color: C.inputBg, borderRadius: BorderRadius.circular(12.px)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            key: const Key('f_station'),
                            isExpanded: true,
                            value: _stationId,
                            dropdownColor: C.cream,
                            style: ts(12),
                            hint: Text('Select station', style: ts(11, color: C.hint)),
                            items: [
                              DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('No station (in workshop)',
                                      style: ts(12, color: C.muted))),
                              for (final s in stations)
                                DropdownMenuItem<int?>(
                                  value: s.stationId,
                                  child: Text(
                                      '${s.stationName}  ·  ${store.availability(s).freeSlots} free'),
                                ),
                            ],
                            onChanged: (v) => setState(() => _stationId = v),
                          ),
                        ),
                      ),
                    // ---- แบตเตอรี่
                    Row(
                      children: [
                        Expanded(child: Text('Battery level', style: ts(11, color: C.muted))),
                        Text('${_battery.round()}%',
                            style: ts(12,
                                w: FontWeight.w500,
                                color: _battery < 20 ? C.redText : C.ink)),
                      ],
                    ),
                    Bar(_battery.round(), red: _battery < 20),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: C.gold,
                        inactiveTrackColor: C.line,
                        thumbColor: C.red,
                        overlayColor: C.redBg,
                      ),
                      child: Slider(
                        key: const Key('f_battery'),
                        value: _battery,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        onChanged: (v) => setState(() => _battery = v),
                      ),
                    ),
                    // ---- สถานะ
                    Text('Status', style: ts(11, color: C.muted)),
                    if (_isBorrowed)
                      const Align(
                          alignment: Alignment.centerLeft,
                          child: VehicleStatusPill(VehicleStatus.borrowed))
                    else
                      Chips([for (final s in _editable) s.label],
                          selected: _editable.indexOf(_status).clamp(0, _editable.length - 1),
                          onSelect: (i) => setState(() => _status = _editable[i])),
                  ], h: 7),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.px, 0, 12.px, 8.px),
              child: Btn(_isEdit ? 'Save changes' : 'Add vehicle',
                  key: const Key('btn_save_vehicle'), icon: TablerIcons.check, onTap: _save),
            ),
          ],
        ),
      ),
    );
  }
}
