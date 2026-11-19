// แท็บ Stations: ดูช่องจอด/รถในแต่ละสถานี, แก้ชื่อ-จำนวนช่อง, ปิดสถานีชั่วคราว, เพิ่มสถานี
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../core/photo_picker.dart';
import '../data/models.dart';
import 'admin_ui.dart';
import '../widgets/basic.dart';
import '../widgets/form.dart';
import '../widgets/station_pic.dart';
import 'sheets.dart';

class StationsTab extends StatefulWidget {
  const StationsTab({super.key});

  @override
  State<StationsTab> createState() => _StationsTabState();
}

class _StationsTabState extends State<StationsTab> {
  final Set<int> _open = {}; // สถานีที่กางดูรถอยู่

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Column(
        children: [
          TabHeader('Stations',
              subtitle: '${s.allStations.length} stations · tap to see vehicles',
              trailing: AddCircle(
                  tooltip: 'Add station', onTap: () => editStation(context, null))),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 16.px),
              children: gapped([
                for (final st in s.allStations)
                  _StationCard(
                    st,
                    open: _open.contains(st.stationId),
                    onToggle: () => setState(() => _open.contains(st.stationId)
                        ? _open.remove(st.stationId)
                        : _open.add(st.stationId)),
                  ),
              ], h: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard(this.st, {required this.open, required this.onToggle});
  final Station st;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = AppStore.instance;
    final a = s.availability(st);
    final used = st.totalDocks - a.freeDocks;
    final list = s.vehiclesAt(st.stationId);
    final charging = list.where(s.isCharging).length;
    final repair = list.where((v) => v.status == VehicleStatus.maintenance).length;
    final (label, kind) = !st.isActive
        ? ('Closed', PillKind.gray)
        : a.full
            ? ('Full', PillKind.red)
            : a.ready == 0
                ? ('No vehicles', PillKind.red)
                : ('${a.ready} ready', PillKind.gold);

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: EdgeInsets.all(10.px),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: open ? C.red.withValues(alpha: 0.45) : C.line, width: 1.2.px),
          borderRadius: BorderRadius.circular(16.px),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: gapped([
            Row(
              children: gapped([
                StationPic(st,
                    !st.isActive ? Tint.off : (a.ready == 0 || a.full ? Tint.none : Tint.ready),
                    size: 38),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.name, style: ts(13, w: FontWeight.w600)),
                      Text(
                          '${a.readyBikes} ${a.readyBikes == 1 ? 'bike' : 'bikes'} · '
                          '${a.readyScooters} ${a.readyScooters == 1 ? 'scooter' : 'scooters'}',
                          style: muStyle),
                    ],
                  ),
                ),
                Pill(label, kind: kind),
                InkWell(
                  onTap: () => editStation(context, st),
                  child: Padding(
                    padding: EdgeInsets.all(4.px),
                    child: Icon(TablerIcons.pencil, size: 16.px, color: C.chipText),
                  ),
                ),
              ], w: 8),
            ),
            Row(children: [
              Text('Docks used', style: ts(10, color: C.chipText)),
              const Spacer(),
              Text('$used / ${st.totalDocks}', style: ts(10, w: FontWeight.w500)),
            ]),
            Bar((used / st.totalDocks * 100).round(), red: a.full),
            Row(children: [
              if (charging > 0) ...[
                Icon(TablerIcons.plugConnected, size: 11.px, color: Tint.charging.fg),
                Text(' $charging charging   ', style: ts(10, color: Tint.charging.fg)),
              ],
              if (repair > 0) ...[
                Icon(TablerIcons.tool, size: 11.px, color: C.grayPillText),
                Text(' $repair in repair', style: ts(10, color: C.grayPillText)),
              ],
              const Spacer(),
              Icon(open ? TablerIcons.chevronUp : TablerIcons.chevronDown,
                  size: 14.px, color: C.chipText),
            ]),
            if (open) ...[
              if (list.isEmpty) Text('No vehicles parked here', style: muStyle),
              for (final v in list)
                AppCard(onTap: () => showVehicleSheet(context, v), children: [
                  TintIc(s.typeOf(v).icon, vehicleTint(v)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.code, style: ts(12, w: FontWeight.w500)),
                        SizedBox(height: 4.px),
                        Bar(s.liveBattery(v), red: s.liveBattery(v) < AppStore.minBattery),
                      ],
                    ),
                  ),
                  Text('${s.liveBattery(v)}%', style: ts(11, w: FontWeight.w500)),
                  Pill(vehicleBadge(v).$1, kind: vehicleBadge(v).$2),
                ]),
            ],
          ], h: 7),
        ),
      ),
    );
  }
}

/// เพิ่ม (st = null) / แก้สถานี: ชื่อ, จำนวนช่องจอด, เปิด-ปิดใช้งาน
Future<void> editStation(BuildContext context, Station? st) async {
  final name = TextEditingController(text: st?.name ?? '');
  final docks = TextEditingController(text: '${st?.totalDocks ?? 10}');
  var active = st?.isActive ?? true;
  var iconKey = st?.iconKey ?? 'building';
  Uint8List? photo = st?.photo;
  var removePhoto = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        scrollable: true, // เนื้อหายาว (มีส่วนรูป) เลื่อนได้ ไม่ล้นจอ
        backgroundColor: C.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.px)),
        title: Text(st == null ? 'Add station' : 'Edit station', style: ts(14, w: FontWeight.w600)),
        content: SizedBox(
          width: 260.px,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: gapped([
            AppInput(controller: name, hint: 'e.g. Library', label: 'Station name'),
            // ---------- รูปสถานี (ผู้ใช้เห็นในหน้า Home และหน้าเลือกรถ)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Picture', style: ts(11, color: C.chipText)),
            ),
            Row(
              children: [
                if (photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.px),
                    child: Image.memory(photo!, width: 64.px, height: 48.px, fit: BoxFit.cover),
                  )
                else
                  TintIc(stationIcon(iconKey), Tint.ready, size: 44),
                SizedBox(width: 8.px),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canPickPhoto)
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () async {
                            final bytes = await pickPhotoBytes();
                            if (bytes == null) return;
                            if (bytes.length > 5 * 1024 * 1024) {
                              if (context.mounted) {
                                toast(context, 'Please choose a photo under 5 MB', error: true);
                              }
                              return;
                            }
                            setD(() {
                              photo = bytes;
                              removePhoto = false;
                            });
                          },
                          icon: Icon(TablerIcons.upload, size: 14.px, color: C.red),
                          label: Text(photo == null ? 'Upload photo' : 'Change photo',
                              style: ts(11, w: FontWeight.w500, color: C.red)),
                        ),
                      if (photo != null)
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => setD(() {
                            photo = null;
                            removePhoto = true;
                          }),
                          child: Text('Remove photo – use icon',
                              style: ts(11, color: C.chipText)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (photo == null)
              Wrap(
                spacing: 6.px,
                runSpacing: 6.px,
                children: [
                  for (final (key, icon, label) in stationIcons)
                    Tooltip(
                      message: label,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setD(() => iconKey = key),
                        child: Container(
                          width: 34.px,
                          height: 34.px,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: key == iconKey ? C.red : C.inputBg,
                          ),
                          child: Icon(icon,
                              size: 17.px, color: key == iconKey ? Colors.white : C.chipText),
                        ),
                      ),
                    ),
                ],
              ),
            TextField(
              controller: docks,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: ts(12),
              decoration: InputDecoration(
                labelText: 'Total docks',
                labelStyle: ts(11, color: C.chipText),
                isDense: true,
                filled: true,
                fillColor: C.inputBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.px), borderSide: BorderSide.none),
              ),
            ),
            if (st != null)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Open for riders', style: ts(12)),
                        Text('Turn off to close this station', style: muStyle),
                      ],
                    ),
                  ),
                  Switch(
                    value: active,
                    activeTrackColor: C.red,
                    onChanged: (v) => setD(() => active = v),
                  ),
                ],
              ),
          ], h: 10),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: ts(11, color: C.chipText))),
          TextButton(
            onPressed: () async {
              final store = AppStore.instance;
              final err = await store.saveStation(st,
                  name: name.text, docks: int.tryParse(docks.text) ?? 0, active: active);
              if (!context.mounted) return;
              if (err != null) return toast(context, err, error: true);
              // สถานีใหม่ = หาจากชื่อที่เพิ่งบันทึก
              final target = st ??
                  store.allStations.firstWhere((x) => x.name == name.text.trim(),
                      orElse: () => store.allStations.last);
              // ส่งรูปขึ้น backend เฉพาะตอนเลือกรูปใหม่ (รูปเดิมที่โหลดมาแสดงไม่ต้องอัปโหลดซ้ำ)
              final lookErr = await store.setStationLook(target,
                  iconKey: iconKey,
                  photo: identical(photo, target.photo) ? null : photo,
                  removePhoto: removePhoto);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              if (lookErr != null) return toast(context, lookErr, error: true);
              toast(context, st == null ? 'Station added' : 'Station saved');
            },
            child: Text('Save', style: ts(11, w: FontWeight.w600, color: C.red)),
          ),
        ],
      ),
    ),
  );
}
