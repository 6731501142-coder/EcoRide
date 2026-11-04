// หน้า 2) Station details – รายละเอียดสถานีและรายการรถ
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/models.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';
import 'vehicle_details_screen.dart';

class StationDetailsScreen extends StatefulWidget {
  const StationDetailsScreen({super.key, required this.station});
  final Station station;

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  int _chip = 0;

  @override
  Widget build(BuildContext context) {
    Ui.init(context);
    final s = widget.station;
    final list = s.vehicles.where((v) {
      if (_chip == 1) return v.type == VType.bike;
      if (_chip == 2) return v.type == VType.scooter;
      return true;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: s.name,
              leading: BackIcon(),
              trailing: Icon(TablerIcons.heart, size: 13.px, color: C.ink),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(12.px, 6.px, 12.px, 7.px),
                child: Column(
                  children: gapped([
                    _MapPreview(),
                    Row(
                      children: gapped([
                        Expanded(child: Kpi('${s.ready}', 'Ready to ride')),
                        Expanded(child: Kpi('${s.freeDocks}/${s.totalDocks}', 'Free docks')),
                      ], w: 7),
                    ),
                    Chips(
                      ['All', 'E-bikes', 'Scooters'],
                      selected: _chip,
                      onSelect: (i) => setState(() => _chip = i),
                    ),
                    for (final v in list) _VehicleTile(v),
                  ], h: 7),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.px, 0, 12.px, 8.px),
              child: Btn(
                'Scan QR to borrow',
                icon: TablerIcons.qrcode,
                onTap: () {}, // TODO: เชื่อมหน้าสแกน QR / back-end
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// .map – แผนที่จำลอง (หมุด 3 จุดตามตำแหน่ง % ของต้นแบบ)
class _MapPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78.px,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: C.goldBg,
        borderRadius: BorderRadius.circular(16.px),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          Widget pin(double fx, double fy, Color color) => Positioned(
                left: box.maxWidth * fx,
                top: box.maxHeight * fy,
                child: Icon(TablerIcons.mapPin, size: 20.px, color: color),
              );
          return Stack(
            children: [
              pin(.30, .30, C.gold),
              pin(.58, .42, C.red),
              pin(.78, .18, C.gold),
            ],
          );
        },
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile(this.v);
  final Vehicle v;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VehicleDetailsScreen(vehicle: v)),
      ),
      children: [
        Ic(v.icon, red: v.low),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.id, style: ttStyle),
              Padding(
                padding: EdgeInsets.only(top: 3.px),
                child: Bar(v.battery, red: v.low),
              ),
            ],
          ),
        ),
        Pill(v.low ? 'Low battery' : '${v.battery}%',
            kind: v.low ? PillKind.red : PillKind.gold),
      ],
    );
  }
}
