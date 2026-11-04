// ข้อมูลตัวอย่าง (ยังไม่มี back-end)
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'models.dart';

const kStations = <Station>[
  Station(
    name: 'Building A',
    icon: TablerIcons.building,
    summary: '4 bikes · 2 scooters',
    badge: '6 free',
    ready: 6,
    freeDocks: 3,
    totalDocks: 10,
    vehicles: [
      Vehicle(id: 'EB-005', type: VType.bike, battery: 92, station: 'Building A', rangeKm: 26),
      Vehicle(id: 'EB-021', type: VType.bike, battery: 67, station: 'Building A', rangeKm: 19),
      Vehicle(id: 'ES-019', type: VType.scooter, battery: 80, station: 'Building A', rangeKm: 16),
    ],
  ),
  Station(
    name: 'Library',
    icon: TablerIcons.books,
    summary: '1 bike · 5 scooters',
    badge: '6 free',
    ready: 6,
    freeDocks: 4,
    totalDocks: 10,
    vehicles: [
      Vehicle(id: 'EB-012', type: VType.bike, battery: 86, station: 'Library', rangeKm: 24),
      Vehicle(id: 'ES-027', type: VType.scooter, battery: 54, station: 'Library', rangeKm: 11),
      Vehicle(id: 'ES-031', type: VType.scooter, battery: 12, station: 'Library', rangeKm: 3),
    ],
  ),
  Station(
    name: 'Canteen',
    icon: TablerIcons.toolsKitchen2,
    summary: '0 bikes · 1 scooter',
    badge: 'Low',
    low: true,
    ready: 1,
    freeDocks: 5,
    totalDocks: 8,
    vehicles: [
      Vehicle(id: 'ES-014', type: VType.scooter, battery: 45, station: 'Canteen', rangeKm: 9),
    ],
  ),
];
