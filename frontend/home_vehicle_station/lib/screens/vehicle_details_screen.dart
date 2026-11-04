// หน้า 3) Vehicle details – รายละเอียดรถ
import 'package:flutter/material.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/models.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';

class VehicleDetailsScreen extends StatelessWidget {
  const VehicleDetailsScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    Ui.init(context);
    final v = vehicle;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'Vehicle details', leading: BackIcon()),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(12.px, 6.px, 12.px, 7.px),
                child: Column(
                  children: gapped([
                    // รูปรถ
                    Container(
                      height: 120.px,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: C.goldBg,
                        borderRadius: BorderRadius.circular(22.px),
                      ),
                      child: Icon(v.icon, size: 70.px, color: C.red),
                    ),
                    // ชื่อ + สถานะ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.id, style: ts(15, w: FontWeight.w500)),
                            Text(v.typeLabel, style: muStyle),
                          ],
                        ),
                        Pill(v.low ? 'Low battery' : 'Available',
                            kind: v.low ? PillKind.red : PillKind.gold),
                      ],
                    ),
                    // แบตเตอรี่ + แถบ
                    Column(
                      children: [
                        _InfoRow('Battery', '${v.battery}%'),
                        Padding(
                          padding: EdgeInsets.only(top: 3.px),
                          child: Bar(v.battery, red: v.low),
                        ),
                      ],
                    ),
                    _InfoRow('Current station', v.station),
                    _InfoRow('Est. range', '~ ${v.rangeKm} km'),
                  ], h: 7),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.px, 0, 12.px, 8.px),
              child: Btn(
                'Borrow this vehicle',
                onTap: () {}, // TODO: เชื่อม back-end ยืมรถ
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// .row2 – แถว label / value
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5.px),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.lineRow, width: 1.px)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: muStyle),
          Text(value, style: ttStyle),
        ],
      ),
    );
  }
}
