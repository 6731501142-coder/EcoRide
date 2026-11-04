import 'package:flutter/material.dart';

class ChooseReturnStationPage extends StatefulWidget {
  const ChooseReturnStationPage({super.key});

  @override
  State<ChooseReturnStationPage> createState() => _ChooseReturnStationPageState();
}

class _ChooseReturnStationPageState extends State<ChooseReturnStationPage> {
  int? selectedStationId;

  final List<dynamic> stations = [
    {
      'id': 1,
      'name': 'อาคาร A (Building A Station)',
      'distance': '300 เมตร',
      'availableDocks': 4,
      'totalDocks': 10,
      'status': 'available',
    },
    {
      'id': 2,
      'name': 'หอสมุดกลาง (Central Library)',
      'distance': '850 เมตร',
      'availableDocks': 6,
      'totalDocks': 10,
      'status': 'available',
    },
    {
      'id': 3,
      'name': 'โรงอาหารกลาง (Main Canteen)',
      'distance': '1.2 กิโลเมตร',
      'availableDocks': 0,
      'totalDocks': 8,
      'status': 'full',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
          'เลือกสถานีคืนรถ ✨',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFFFDE047)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              border: Border(
                bottom: BorderSide(color: Color(0xFFFCA5A5), width: 1),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.directions_bike, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'กำลังใช้งาน: E-Bike #EB-012 (ระยะเวลา 18 นาที)',
                    style: TextStyle(
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stations.length,
              itemBuilder: (context, index) {
                final station = stations[index];
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
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isFull ? const Color(0xFFF3F4F6) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD97706)
                            : (isFull ? Colors.transparent : const Color(0xFFFEE2E2)),
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? const Color(0xFFD97706).withOpacity(0.2)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFFD97706)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFD97706)
                                  : (isFull
                                      ? Colors.grey
                                      : const Color(0xFFFCA5A5)),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                station['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isFull
                                      ? Colors.grey.shade600
                                      : const Color(0xFF7F1D1D),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      size: 14, color: Color(0xFFD97706)),
                                  const SizedBox(width: 2),
                                  Text(
                                    station['distance'],
                                    style: const TextStyle(
                                      color: Color(0xFFB45309),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isFull
                                ? const Color(0xFFE5E7EB)
                                : (isSelected
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFFEF2F2)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isFull
                                ? 'ช่องจอดเต็ม ❌'
                                : 'ว่าง ${station['availableDocks']}/${station['totalDocks']} ช่อง 🚲',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isFull
                                  ? Colors.grey.shade700
                                  : (isSelected
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 15,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: selectedStationId == null ? null : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      selectedStationId == null
                          ? 'โปรดเลือกสถานีคืนรถ 📍'
                          : 'ยืนยันการคืนรถที่สถานีนี้ ✨',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (selectedStationId != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}