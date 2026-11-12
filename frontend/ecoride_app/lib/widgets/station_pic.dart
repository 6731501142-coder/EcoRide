// รูปของสถานี: รูปถ่ายที่แอดมินอัปโหลด → ถ้าไม่มี ใช้ไอคอนสำเร็จรูปที่แอดมินเลือก
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/ui.dart';
import '../data/models.dart';
import 'basic.dart';

/// ไอคอนสำเร็จรูปให้แอดมินเลือก (เก็บลง DB แค่ key)
const stationIcons = <(String, IconData, String)>[
  ('building', TablerIcons.building, 'Building'),
  ('school', TablerIcons.school, 'Faculty'),
  ('books', TablerIcons.books, 'Library'),
  ('flask', TablerIcons.flask, 'Science'),
  ('canteen', TablerIcons.toolsKitchen2, 'Canteen'),
  ('dorm', TablerIcons.bed, 'Dorm'),
  ('sport', TablerIcons.ballFootball, 'Sports'),
  ('park', TablerIcons.trees, 'Park'),
  ('parking', TablerIcons.parking, 'Parking'),
];

IconData stationIcon(String key) {
  for (final (k, icon, _) in stationIcons) {
    if (k == key) return icon;
  }
  return TablerIcons.building;
}

class StationPic extends StatelessWidget {
  const StationPic(this.station, this.tint, {super.key, this.size = 30});
  final Station station;
  final Tint tint; // สีตามสถานะ (เขียว/ทอง/แดง/เทา) ใช้กับไอคอน และเป็นขอบของรูปถ่าย
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = station.photo;
    if (photo == null) return TintIc(stationIcon(station.iconKey), tint, size: size);
    return Container(
      width: size.px,
      height: size.px,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tint.fg, width: 1.6.px),
        image: DecorationImage(image: MemoryImage(photo), fit: BoxFit.cover),
      ),
    );
  }
}

/// ภาพใหญ่ด้านบนหน้าเลือกรถ (แสดงเมื่อมีรูปถ่าย)
class StationBanner extends StatelessWidget {
  const StationBanner(this.station, {super.key});
  final Station station;

  @override
  Widget build(BuildContext context) {
    final photo = station.photo;
    if (photo == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.px),
      child: Image.memory(photo, height: 120.px, width: double.infinity, fit: BoxFit.cover),
    );
  }
}
