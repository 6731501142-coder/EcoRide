import 'package:flutter/material.dart';

class BorrowingHistoryPage extends StatelessWidget {
  const BorrowingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> history = [
      {
        'vehicle': 'E-Bike #EB-012',
        'type': 'bike',
        'time': '1 พ.ย. 2026 • 09:42 - 10:05',
        'start': 'หอสมุดกลาง (Central Library)',
        'end': 'อาคาร A (Building A Station)',
        'duration': '23 นาที',
        'cost': '฿ 0.00',
        'status': 'สำเร็จ',
      },
      {
        'vehicle': 'E-Scooter #ES-027',
        'type': 'scooter',
        'time': '30 ต.ค. 2026 • 16:15 - 16:30',
        'start': 'โรงอาหารกลาง (Main Canteen)',
        'end': 'หอสมุดกลาง (Central Library)',
        'duration': '15 นาที',
        'cost': '฿ 0.00',
        'status': 'สำเร็จ',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDC2626),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'History',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(width: 6),
            Text('✨', style: TextStyle(fontSize: 16)),
          ],
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              children: [
                // 1. Banner สรุปสถิติ (ปรับเหลือ 2 ช่อง: ยืมทั้งหมด 2 ครั้ง และ เวลารวม 38 นาที)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE52E2E), Color(0xFFD96B00)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(label: 'ยืมทั้งหมด', value: '2 ครั้ง'),
                      _StatDivider(),
                      _StatItem(label: 'เวลารวม', value: '38 นาที'),
                    ],
                  ),
                ),

                // 2. รายการประวัติการยืม-คืน
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFEF08A), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header การ์ด
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      item['type'] == 'bike'
                                          ? Icons.directions_bike
                                          : Icons.electric_scooter,
                                      color: const Color(0xFF1E293B),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item['vehicle'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF8B0000),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F4EA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    item['status'],
                                    style: const TextStyle(
                                      color: Color(0xFF137333),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // เส้นทาง
                            Text(
                              'ต้นทาง: ${item['start']}',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ปลายทาง: ${item['end']}',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),

                            // ท้ายการ์ด
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ระยะเวลา: ${item['duration']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  item['cost'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFFD96B00),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Sub-Widget แสดงตัวเลขสถิติ
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

// Sub-Widget เส้นแบ่งคอลัมน์
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: Colors.white30);
  }
}
