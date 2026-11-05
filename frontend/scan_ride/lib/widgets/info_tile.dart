import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// การ์ดข้อมูลมาตรฐานของแอป: ไอคอนวงกลมทองอ่อน + หัวข้อ + คำอธิบาย
/// ใช้ซ้ำทั้งหน้า Scan (การ์ดรถ) และหน้า Active Riding (Battery / From / Nearby)
class InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? bottom; // เช่น แถบ progress ของแบตเตอรี่
  final Widget? trailing; // เช่น ชิป Ready

  const InfoTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.bottom,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.goldSoft,
            child: Icon(icon, color: AppColors.goldDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ),
                if (bottom != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8), child: bottom!),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// ชิปสถานะเล็ก ๆ เช่น "Ready" (ทอง) หรือ "Unavailable" / "Low" (แดงอ่อน)
class StatusChip extends StatelessWidget {
  final String label;
  final bool positive;

  const StatusChip({super.key, required this.label, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: positive ? AppColors.goldSoft : AppColors.blush,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: positive ? AppColors.goldDark : AppColors.crimson,
        ),
      ),
    );
  }
}
