import 'package:flutter/material.dart';

class ChooseReturnStationPage extends StatefulWidget {
  const ChooseReturnStationPage({super.key});

  @override
  State<ChooseReturnStationPage> createState() => _ChooseReturnStationPageState();
}

class _ChooseReturnStationPageState extends State<ChooseReturnStationPage> {
  int? selectedStationId;
  String searchQuery = ""; // เพิ่มตัวแปรเก็บคำค้นหา

  final List<dynamic> stations = [
    {
      'id': 1,
      'name': 'สถานีหอสมุดกลาง ⭐️',
      'distance': '320 ม.',
      'availableDocks': 4,
      'totalDocks': 10,
      'status': 'available',
    },
    {
      'id': 2,
      'name': 'สถานีอาคาร A (Building A)',
      'distance': '150 ม.',
      'availableDocks': 6,
      'totalDocks': 10,
      'status': 'available',
    },
    {
      'id': 3,
      'name': 'สถานีโรงอาหารกลาง 🍲',
      'distance': '550 ม.',
      'availableDocks': 0,
      'totalDocks': 8,
      'status': 'full',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // กรองสถานีตามคำค้นหาในช่อง Search
    final filteredStations = stations.where((station) {
      final name = station['name'].toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    final selectedStation = stations.firstWhere(
      (s) => s['id'] == selectedStationId,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header สีแดงสด Gradient
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C), Color(0xFF881337)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFFDE047), size: 18),
                        onPressed: () {
                          if (Navigator.canPop(context)) Navigator.pop(context);
                        },
                      ),
                      const Column(
                        children: [
                          Text(
                            '📍 เลือกสถานีคืนรถ',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'Choose Return Station ✨',
                            style: TextStyle(color: Color(0xFFFDE047), fontSize: 11),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite, color: Color(0xFFFDE047), size: 20),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE047).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE047),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.directions_bike, color: Color(0xFF881337), size: 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('EB-012', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFACC15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('กำลังใช้งาน', style: TextStyle(color: Color(0xFF881337), fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const Text('⏱️ ยืมแล้ว 23 นาที', style: TextStyle(color: Color(0xFFFEF08A), fontSize: 11)),
                            ],
                          ),
                        ),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('⚡ 86%', style: TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('แบตเตอรี่คงเหลือ', style: TextStyle(color: Colors.white70, fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. แผนที่จำลอง (กดที่หมุด P แล้วเด้งเลือกสถานีทันที)
            Container(
              height: 110,
              width: double.infinity,
              color: const Color(0xFFFFF7ED),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                        itemBuilder: (ctx, i) => Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 35,
                    left: 60,
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(0xFFDC2626),
                          child: Icon(Icons.person, size: 10, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF881337), borderRadius: BorderRadius.circular(8)),
                          child: const Text('คุณอยู่ที่นี่ 📍', style: TextStyle(color: Color(0xFFFEF08A), fontSize: 8)),
                        ),
                      ],
                    ),
                  ),
                  // หมุด อาคาร A (id: 2)
                  Positioned(
                    top: 15,
                    right: 90,
                    child: _buildMapPin(
                      'อาคาร A (ว่าง 6)',
                      isFull: false,
                      onTap: () => setState(() => selectedStationId = 2),
                    ),
                  ),
                  // หมุด หอสมุด (id: 1)
                  Positioned(
                    bottom: 25,
                    left: 120,
                    child: _buildMapPin(
                      'หอสมุด (ว่าง 4)',
                      isFull: false,
                      onTap: () => setState(() => selectedStationId = 1),
                    ),
                  ),
                  // หมุด โรงอาหาร (id: 3 - เต็ม)
                  Positioned(
                    bottom: 15,
                    right: 40,
                    child: _buildMapPin(
                      'โรงอาหาร (เต็ม)',
                      isFull: true,
                      onTap: null, // เต็ม กดเลือกไม่ได้
                    ),
                  ),
                ],
              ),
            ),

            // 3. ช่องค้นหาใช้งานได้จริง + ปุ่มกรอง
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFEF08A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                setState(() {
                                  searchQuery = val;
                                });
                              },
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'ค้นหาชื่อสถานี หรือ ตึก...',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF08A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFACC15)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.tune, color: Color(0xFF881337), size: 16),
                        SizedBox(width: 4),
                        Text('กรอง', style: TextStyle(color: Color(0xFF881337), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. รายการสถานีคืนรถ (แสดงผลตามค้นหา)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredStations.length,
                itemBuilder: (context, index) {
                  final station = filteredStations[index];
                  final bool isSelected = selectedStationId == station['id'];
                  final bool isFull = station['status'] == 'full';

                  return GestureDetector(
                    onTap: isFull
                        ? null
                        : () {
                            setState(() {
                              selectedStationId = station['id'];
                            });
                          },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isFull ? const Color(0xFFF3F4F6) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFDC2626)
                              : (isFull ? Colors.transparent : const Color(0xFFFEF08A)),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? const Color(0xFFDC2626) : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  station['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isFull ? Colors.grey.shade600 : const Color(0xFF881337),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '📍 หน้าทางเข้าหลัก',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isFull ? Colors.grey.shade200 : const Color(0xFFFEF08A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isFull ? 'ช่องจอดเต็ม ❌' : '🅿️ ว่าง ${station['availableDocks']}/${station['totalDocks']} ช่อง',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isFull ? Colors.grey.shade700 : const Color(0xFF881337),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            station['distance'],
                            style: TextStyle(
                              color: isFull ? Colors.grey : const Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 5. Card สรุปและปุ่มยืนยันด้านล่าง
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFEF08A)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('สถานีปลายทางที่เลือก', style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                            Text(
                              selectedStation != null ? selectedStation['name'] : 'กรุณาเลือกสถานี',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('ค่าบริการประมาณ', style: TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                            Text('฿0.00 (นักศึกษา)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: selectedStationId == null ? null : () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedStationId == null ? const Color(0xFFE2E8F0) : const Color(0xFFDC2626),
                        foregroundColor: selectedStationId == null ? const Color(0xFF94A3B8) : Colors.white,
                        elevation: selectedStationId == null ? 0 : 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (selectedStationId != null) const Icon(Icons.check_circle, size: 18),
                          if (selectedStationId != null) const SizedBox(width: 6),
                          Text(
                            selectedStationId == null ? 'ยืนยันสถานีคืนรถ' : 'ยืนยันการคืนรถที่สถานีนี้ ✨',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget หมุดแผนที่ เพิ่ม onTap ให้กดคลิกได้
  Widget _buildMapPin(String label, {bool isFull = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isFull ? Colors.grey.shade400 : const Color(0xFFFACC15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'P',
              style: TextStyle(
                color: isFull ? Colors.white : const Color(0xFF881337),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
            child: Text(
              label,
              style: TextStyle(
                color: isFull ? Colors.grey.shade600 : const Color(0xFF881337),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
