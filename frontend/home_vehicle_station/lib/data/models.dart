// โมเดลข้อมูล: Vehicle และ Station
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

enum VType { bike, scooter }

class Vehicle {
  const Vehicle({
    required this.id,
    required this.type,
    required this.battery,
    required this.station,
    required this.rangeKm,
  });

  final String id;
  final VType type;
  final int battery;
  final String station;
  final int rangeKm;

  String get typeLabel =>
      type == VType.bike ? 'Electric bicycle' : 'Electric scooter';
  IconData get icon =>
      type == VType.bike ? TablerIcons.bike : TablerIcons.scooterElectric;
  bool get low => battery <= 20;
}

class Station {
  const Station({
    required this.name,
    required this.icon,
    required this.summary,
    required this.badge,
    required this.ready,
    required this.freeDocks,
    required this.totalDocks,
    required this.vehicles,
    this.low = false,
  });

  final String name;
  final IconData icon;
  final String summary;
  final String badge;
  final int ready;
  final int freeDocks;
  final int totalDocks;
  final bool low;
  final List<Vehicle> vehicles;
}
