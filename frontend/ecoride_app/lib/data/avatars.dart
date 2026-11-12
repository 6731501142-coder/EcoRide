// อวาตาร์สำเร็จรูป (แบบ Discord) – ให้คนที่ไม่อยากอัปโหลดรูปเลือกได้เลย
// เก็บลง DB แค่เลข id (เช่น users.avatar_id) ไม่ต้องอัปโหลดไฟล์ ใช้ได้ทุกแพลตฟอร์ม
import 'package:flutter/widgets.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

class PresetAvatar {
  const PresetAvatar(this.id, this.icon, this.bg, this.fg);
  final int id;
  final IconData icon;
  final Color bg; // สีพื้นวงกลม
  final Color fg; // สีไอคอน
}

const presetAvatars = <PresetAvatar>[
  PresetAvatar(1, TablerIcons.bike, Color(0xFFC8323C), Color(0xFFFFFFFF)),
  PresetAvatar(2, TablerIcons.scooterElectric, Color(0xFFE2B04A), Color(0xFF3A1F22)),
  PresetAvatar(3, TablerIcons.bolt, Color(0xFF3A1F22), Color(0xFFE2B04A)),
  PresetAvatar(4, TablerIcons.leaf, Color(0xFF2F6B40), Color(0xFFE5F3E8)),
  PresetAvatar(5, TablerIcons.rocket, Color(0xFF2C5A88), Color(0xFFE6EFFA)),
  PresetAvatar(6, TablerIcons.planet, Color(0xFF5D3F8C), Color(0xFFF0E9FA)),
  PresetAvatar(7, TablerIcons.cat, Color(0xFFF2994A), Color(0xFFFFFFFF)),
  PresetAvatar(8, TablerIcons.dog, Color(0xFF8D6E63), Color(0xFFFFF3E0)),
  PresetAvatar(9, TablerIcons.ghost, Color(0xFF9AA5B1), Color(0xFFFFFFFF)),
  PresetAvatar(10, TablerIcons.sun, Color(0xFFFBC02D), Color(0xFF6E5410)),
  PresetAvatar(11, TablerIcons.moon, Color(0xFF283593), Color(0xFFFFF59D)),
  PresetAvatar(12, TablerIcons.flame, Color(0xFFE64A19), Color(0xFFFFF3E0)),
  PresetAvatar(13, TablerIcons.coffee, Color(0xFF6D4C41), Color(0xFFFBF1DA)),
  PresetAvatar(14, TablerIcons.music, Color(0xFFD81B60), Color(0xFFFFFFFF)),
  PresetAvatar(15, TablerIcons.star, Color(0xFF00897B), Color(0xFFFFF59D)),
  PresetAvatar(16, TablerIcons.heart, Color(0xFFFCE8EA), Color(0xFFC8323C)),
];

PresetAvatar? presetAvatarById(int? id) {
  for (final a in presetAvatars) {
    if (a.id == id) return a;
  }
  return null;
}
