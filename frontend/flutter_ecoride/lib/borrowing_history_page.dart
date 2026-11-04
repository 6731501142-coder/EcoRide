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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {},
        ),
        title: const Text(
          'ประวัติการยืม-คืน ✨',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'ยืมทั้งหมด', value: '12 ครั้ง'),
                _StatDivider(),
                _StatItem(label: 'เวลารวม', value: '4.5 ชม.'),
                _StatDivider(),
                _StatItem(label: 'ลดคาร์บอน', value: '1.8 kg'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                item['type'] == 'bike'
                                    ? Icons.directions_bike
                                    : Icons.electric_scooter,
                                color: const Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item['vehicle'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7F1D1D),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item['status'],
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text('ต้นทาง: ${item['start']}',
                          style: const TextStyle(fontSize: 12)),
                      Text('ปลายทาง: ${item['end']}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ระยะเวลา: ${item['duration']}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          Text(item['cost'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706))),
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
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: Colors.white30);
  }
}