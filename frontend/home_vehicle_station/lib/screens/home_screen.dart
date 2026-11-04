// หน้า 1) Home – รายการสถานี
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';
import 'station_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _chip = 0;

  @override
  Widget build(BuildContext context) {
    Ui.init(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(12.px, 6.px, 12.px, 8.px),
                child: Column(
                  children: gapped([
                    Row(
                      children: gapped([
                        Expanded(child: Kpi('27', 'Available')),
                        Expanded(child: Kpi('8', 'Stations')),
                        Expanded(child: Kpi('0', 'Borrowed')),
                      ], w: 7),
                    ),
                    Chips(
                      ['All', 'E-bikes', 'Scooters'],
                      selected: _chip,
                      onSelect: (i) => setState(() => _chip = i),
                    ),
                    for (final s in kStations) _StationTile(s),
                  ], h: 7),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavBar(index: 0),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.px, 6.px, 12.px, 14.px),
      decoration: BoxDecoration(
        color: C.red,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22.px)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello,',
                      style: ts(11, color: Color.fromRGBO(255, 255, 255, .85))),
                  Text('Somchai',
                      style: ts(15, w: FontWeight.w500, color: Colors.white)),
                ],
              ),
              Icon(TablerIcons.bell, size: 18.px, color: Colors.white),
            ],
          ),
          SizedBox(height: 7.px),
          SearchField('Search station or building', bg: Colors.white),
        ],
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile(this.s);
  final Station s;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StationDetailsScreen(station: s)),
      ),
      children: [
        Ic(s.icon, red: s.low),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name, style: ttStyle),
              Text(s.summary, style: muStyle),
            ],
          ),
        ),
        Pill(s.badge, kind: s.low ? PillKind.red : PillKind.gold),
      ],
    );
  }
}
