// flow การยืม-คืน:
// หน้า 7 Select bike → หน้า 8 Vehicle detail → หน้า 9 Payment confirm
// → หน้า 10 Summary (นับถอยหลัง 24 ชม.) → หน้า 11 Choose return station → Home
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';
import '../widgets/station_pic.dart';
import '../widgets/form.dart';
import 'account_screens.dart';
import 'help_screen.dart';

/// กลับไปหน้าแรกของ stack (HomeShell) แล้วเปิดหน้าใหม่ทับ
void _backToHomeThen(BuildContext context, [Widget? page]) {
  final nav = Navigator.of(context);
  nav.popUntil((r) => r.isFirst);
  if (page != null) nav.push(MaterialPageRoute(builder: (_) => page));
}

// ======================================================================= หน้า 7 Select bike
class SelectBikeScreen extends StatefulWidget {
  const SelectBikeScreen({super.key, required this.station});
  final Station station;

  @override
  State<SelectBikeScreen> createState() => _SelectBikeScreenState();
}

class _SelectBikeScreenState extends State<SelectBikeScreen> {
  int _filter = 0; // 0 All, 1 E-bikes, 2 Scooters

  /// กดรถคันไหน → เด้งไปหน้า Vehicle detail ของคันนั้นทันที (ปุ่ม Borrow อยู่ในหน้านั้น)
  void _openDetail(BuildContext context, Vehicle v) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: v)));

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = widget.station;
        final a = store.availability(s);
        final list = store.vehiclesAt(s.stationId).where((v) {
          final bike = store.typeOf(v).isBike;
          return _filter == 0 || (_filter == 1 && bike) || (_filter == 2 && !bike);
        }).toList();
        final hasRide = store.activeRide != null;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                TopBar(title: s.name),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 12.px),
                    children: gapped([
                      StationBanner(s), // รูปถ่ายสถานี (ถ้าแอดมินอัปโหลดไว้)
                      Row(
                        children: gapped([
                          Expanded(
                              child: Kpi('${a.ready}', 'Ready to ride',
                                  tone: KpiTone.green, icon: TablerIcons.bolt)),
                          Expanded(
                              child: Kpi('${a.freeDocks}/${s.totalDocks}', 'Free docks',
                                  tone: KpiTone.blue, icon: TablerIcons.parking)),
                        ], w: 8),
                      ),
                      Chips(const ['All', 'E-bikes', 'Scooters'],
                          selected: _filter, onSelect: (i) => setState(() => _filter = i)),
                      if (hasRide)
                        Text('You already have a vehicle out. Return it first.',
                            style: ts(11, color: C.redText)),
                      Text('Pick a vehicle to borrow', style: ts(12, w: FontWeight.w500)),
                      if (list.isEmpty) Text('No vehicles here right now', style: muStyle),
                      for (final v in list) _BikeRow(v, onTap: () => _openDetail(context, v)),
                    ], h: 9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BikeRow extends StatelessWidget {
  const _BikeRow(this.v, {required this.onTap});
  final Vehicle v;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final ok = store.canBorrowVehicle(v);
    final pct = store.liveBattery(v);
    final low = pct < AppStore.minBattery;
    final charging = store.isCharging(v);
    final wait = store.minutesUntilReady(v);
    final isBike = store.typeOf(v).isBike;
    // สีไอคอนตามประเภท: E-bike ฟ้า / Scooter ม่วง (ยืมไม่ได้ = แดง, ซ่อม = เทา)
    final tint = v.status == VehicleStatus.maintenance
        ? Tint.off
        : low
            ? Tint.none
            : isBike
                ? Tint.bike
                : Tint.scooter;
    final (badge, kind) = v.status == VehicleStatus.maintenance
        ? ('Repair', PillKind.gray)
        : ('$pct%', low ? PillKind.red : PillKind.gold);
    return GestureDetector(
      key: Key('bike_${v.code}'),
      onTap: onTap,
      child: Opacity(
        opacity: ok ? 1 : 0.75,
        child: Container(
          padding: EdgeInsets.fromLTRB(10.px, 8.px, 8.px, 8.px),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: C.line, width: 1.px),
            borderRadius: BorderRadius.circular(16.px),
          ),
          child: Row(
            children: [
              TintIc(store.typeOf(v).icon, tint),
              SizedBox(width: 8.px),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // บรรทัด 1: รหัสรถ + % แบต
                    Row(
                      children: [
                        Text(v.code, style: ts(12, w: FontWeight.w500)),
                        const Spacer(),
                        Pill(badge, kind: kind),
                      ],
                    ),
                    SizedBox(height: 5.px),
                    Bar(pct, red: low),
                    // บรรทัด 3: สถานะชาร์จ (แยกบรรทัด จะได้ไม่ล้นจอ)
                    if (charging) ...[
                      SizedBox(height: 4.px),
                      Row(
                        children: [
                          Icon(TablerIcons.plugConnected,
                              size: 11.px, color: wait != null ? C.red : Tint.charging.fg),
                          SizedBox(width: 3.px),
                          Expanded(
                            child: Text(
                              wait != null ? 'Charging · ready in ~$wait min' : 'Charging',
                              overflow: TextOverflow.ellipsis,
                              style: ts(10,
                                  color: wait != null ? C.redText : Tint.charging.fg),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 6.px),
              Icon(TablerIcons.chevronRight, size: 14.px, color: C.chipText),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================= หน้า 8 Vehicle detail
class VehicleDetailScreen extends StatelessWidget {
  const VehicleDetailScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    // ListenableBuilder: แบตที่กำลังชาร์จขยับเองระหว่างเปิดหน้านี้
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final v = vehicle;
        final type = store.typeOf(v);
        final plan = store.defaultPlan;
        final pct = store.liveBattery(v);
        final low = pct < AppStore.minBattery;
        final charging = store.isCharging(v);
        final wait = store.minutesUntilReady(v);
        final ok = store.canBorrowVehicle(v) && store.activeRide == null;
        final tint = type.isBike ? Tint.bike : Tint.scooter;
        final status = switch (v.status) {
          VehicleStatus.available => low ? 'Not ready yet' : 'Available',
          VehicleStatus.inUse => 'In use',
          VehicleStatus.maintenance => 'Repair',
        };
        final spec = AppStore.specOf(type);
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const TopBar(title: 'Vehicle details'),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 12.px),
                    children: gapped([
                      Container(
                        height: 130.px,
                        decoration: BoxDecoration(
                            color: tint.bg, borderRadius: BorderRadius.circular(20.px)),
                        child: Icon(type.icon, size: 70.px, color: tint.fg),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v.code, style: ts(16, w: FontWeight.w500)),
                                Text(type.name, style: muStyle),
                              ],
                            ),
                          ),
                          Pill(status, kind: ok ? PillKind.gold : PillKind.gray),
                        ],
                      ),
                      Row(
                        children: [
                          Text('Battery', style: ts(12, color: C.chipText)),
                          if (charging) ...[
                            SizedBox(width: 6.px),
                            Icon(TablerIcons.plugConnected, size: 13.px, color: Tint.charging.fg),
                            Text(' Charging', style: ts(11, color: Tint.charging.fg)),
                          ],
                          const Spacer(),
                          Text('$pct%', style: ts(12, w: FontWeight.w500)),
                        ],
                      ),
                      Bar(pct, red: low),
                      if (wait != null)
                        Text('Can be borrowed in about $wait min (at ${AppStore.minBattery}%).',
                            style: ts(11, color: C.redText)),
                      Column(
                        children: [
                          InfoRow('Station', v.currentStationId == null
                              ? '—'
                              : store.stationById(v.currentStationId!).name),
                          InfoRow('Range when full',
                              '~${(100 / spec.pctPerKm).round()} km'),
                          InfoRow('Rental plan', plan.name),
                          InfoRow('Price', baht(plan.price),
                              last: true, valueColor: C.red, bold: true),
                        ],
                      ),
                    ], h: 9),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14.px, 0, 14.px, 12.px),
                  child: Btn('Borrow this vehicle',
                      onTap: ok
                          ? () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PaymentConfirmScreen(vehicle: v)))
                          : null),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================================================================= หน้า 9 Payment confirm
class PaymentConfirmScreen extends StatelessWidget {
  const PaymentConfirmScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  /// ปุ่ม Confirm = sp_borrow_vehicle → สำเร็จแล้วไปหน้า Summary
  void _confirm(BuildContext context) {
    final store = AppStore.instance;
    final (ride, err) = store.borrow(vehicle, store.defaultPlan);
    if (ride == null) return toast(context, err!, error: true);
    toast(context, 'Enjoy your ride! Return by ${hm(ride.dueTime)} tomorrow.');
    _backToHomeThen(context, const RideSummaryScreen());
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.me!;
        final plan = store.defaultPlan;
        final after = me.creditBalance - plan.price;
        final enough = after >= 0;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const TopBar(title: 'Payment confirm'),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 12.px),
                    children: gapped([
                      Panel(
                        child: Column(
                          children: [
                            InfoRow('Username', me.username),
                            InfoRow('Bike ID', vehicle.code),
                            InfoRow('Station', store.stationById(vehicle.currentStationId!).name),
                            InfoRow('Plan', '${plan.name} / ${baht(plan.price)}', last: true),
                          ],
                        ),
                      ),
                      Row(
                        children: gapped([
                          Expanded(
                              child: Kpi(baht(me.creditBalance), 'Current credits',
                                  tone: KpiTone.gold, icon: TablerIcons.wallet)),
                          Expanded(
                              child: Kpi(enough ? baht(after) : '—', 'After payment',
                                  tone: enough ? KpiTone.purple : KpiTone.rose,
                                  icon: TablerIcons.arrowRight)),
                        ], w: 8),
                      ),
                      Text(
                        enough
                            ? 'Return within ${plan.durationHours} hours to the station you borrowed from.'
                            : 'Not enough credit. Top up at least ${baht(-after)} to continue.',
                        style: ts(11, color: enough ? C.chipText : C.redText),
                      ),
                      if (!enough)
                        Btn('Add credit',
                            icon: TablerIcons.plus,
                            kind: BtnKind.outlined,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AddCreditScreen()))),
                    ], h: 10),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14.px, 0, 14.px, 12.px),
                  child: Btn('Confirm',
                      key: const Key('btn_confirm_pay'),
                      onTap: enough ? () => _confirm(context) : null),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================================================================= หน้า 10 Summary
class RideSummaryScreen extends StatefulWidget {
  const RideSummaryScreen({super.key});

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // วาดใหม่ทุก 1 วินาที เพื่อให้ตัวนับถอยหลังเดิน
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _countdown(Duration d) {
    final neg = d.isNegative;
    final s = d.abs().inSeconds;
    return '${neg ? '-' : ''}${two(s ~/ 3600)}:${two(s % 3600 ~/ 60)}:${two(s % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final ride = store.activeRide;
    if (ride == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            const TopBar(title: 'Ride'),
            Expanded(child: Center(child: Text('No active ride', style: muStyle))),
          ]),
        ),
      );
    }
    final v = store.vehicleById(ride.vehicleId);
    final from = store.stationById(ride.startStationId).name;
    final left = ride.dueTime.difference(DateTime.now());
    final overdue = left.isNegative;
    return Scaffold(
      body: Column(
        children: [
          RedHeader(
            padding: EdgeInsets.fromLTRB(4.px, 6.px, 4.px, 18.px),
            child: Column(
              children: [
                Row(
                  children: [
                    const BackIcon(color: Colors.white),
                    Expanded(
                      child: Text('Riding · ${v.code}',
                          textAlign: TextAlign.center,
                          style: ts(12, color: const Color(0xFFFFE6E3))),
                    ),
                    SizedBox(width: 34.px),
                  ],
                ),
                Text(overdue ? 'Overdue by' : 'Time left to return',
                    style: ts(11, color: const Color(0xFFFFE6E3))),
                Text(_countdown(left),
                    style: ts(30, w: FontWeight.w600, color: Colors.white)
                        .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                Text('Started ${hm(ride.startTime)} at $from',
                    style: ts(12, color: const Color(0xFFFFE6E3))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(14.px, 12.px, 14.px, 12.px),
              children: gapped([
                AppCard(children: [
                  const Ic(TablerIcons.battery2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Battery ${store.liveBattery(v)}%',
                                style: ts(12, w: FontWeight.w500)),
                            const Spacer(),
                            Text('~${store.estimatedKm(v, ride.usedTime).toStringAsFixed(1)} km · estimated',
                                style: ts(10, color: C.chipText)),
                          ],
                        ),
                        SizedBox(height: 5.px),
                        Bar(store.liveBattery(v),
                            red: store.liveBattery(v) < AppStore.minBattery),
                      ],
                    ),
                  ),
                ]),
                AppCard(children: [
                  const Ic(TablerIcons.mapPin),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From: $from', style: ts(12, w: FontWeight.w500)),
                        Text('Return to this station when you are done', style: muStyle),
                      ],
                    ),
                  ),
                ]),
                AppCard(children: [
                  Ic(TablerIcons.clock, red: overdue),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Borrowed ${dmy(ride.startTime)} · ${hm(ride.startTime)}',
                            style: ts(12, w: FontWeight.w500)),
                        Text('Return by ${dmy(ride.dueTime)} · ${hm(ride.dueTime)}',
                            style: ts(11, color: overdue ? C.redText : C.chipText)),
                      ],
                    ),
                  ),
                ]),
              ], h: 8),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.px, 0, 14.px, 12.px),
              child: Column(
                children: gapped([
                  Btn('Return vehicle',
                      key: const Key('btn_return'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ReturnStationScreen(ride: ride)))),
                  // ฉุกเฉินระหว่างขี่ (อุบัติเหตุ/ยางรั่ว/รถพัง) → เรียกเจ้าหน้าที่มาหา
                  Btn('Need help? Call staff',
                      key: const Key('btn_need_help'),
                      icon: TablerIcons.urgent,
                      kind: BtnKind.outlined,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => HelpScreen(ride: ride)))),
                ], h: 7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================= หน้า 11 Choose return station
class ReturnStationScreen extends StatelessWidget {
  const ReturnStationScreen({super.key, required this.ride});
  final Ride ride;

  /// ปุ่ม Confirm return = sp_return_vehicle
  void _confirm(BuildContext context, Station s) {
    final err = AppStore.instance.returnVehicle(ride, s);
    if (err != null) return toast(context, err, error: true);
    toast(context, 'Returned at ${s.name}. Thank you!');
    _backToHomeThen(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final start = store.stationById(ride.startStationId);
    final startFull = store.availability(start).full;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Choose return station'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14.px, 4.px, 14.px, 12.px),
                children: gapped([
                  Text('Only the station you borrowed from accepts this return.',
                      style: muStyle),
                  for (final s in store.stations) _ReturnRow(s, allowed: s.stationId == start.stationId),
                ], h: 9),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.px, 0, 14.px, 12.px),
              child: Column(
                children: [
                  if (startFull)
                    Padding(
                      padding: EdgeInsets.only(bottom: 6.px),
                      child: Text('${start.name} is full right now. Please wait for a free dock.',
                          style: ts(11, color: C.redText)),
                    ),
                  Btn('Confirm return',
                      key: const Key('btn_confirm_return'),
                      onTap: startFull ? null : () => _confirm(context, start)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnRow extends StatelessWidget {
  const _ReturnRow(this.s, {required this.allowed});
  final Station s;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final a = AppStore.instance.availability(s);
    return Container(
      padding: EdgeInsets.all(8.px),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: allowed ? C.red : C.line, width: allowed ? 1.6.px : 1.px),
        borderRadius: BorderRadius.circular(16.px),
      ),
      child: Row(
        children: gapped([
          allowed ? const Ic(TablerIcons.building) : const _GrayIc(TablerIcons.lock),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: ts(12, w: FontWeight.w500, color: allowed ? C.ink : C.chipText)),
                Text(
                    allowed
                        ? 'Your start station · ${a.freeDocks} / ${s.totalDocks} docks free'
                        : "Can't return here",
                    style: muStyle),
              ],
            ),
          ),
          allowed
              ? Icon(TablerIcons.circleCheck, size: 18.px, color: C.red)
              : const Pill('Locked', kind: PillKind.gray),
        ], w: 8),
      ),
    );
  }
}

class _GrayIc extends StatelessWidget {
  const _GrayIc(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 30.px,
        height: 30.px,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: C.grayPillBg),
        child: Icon(icon, size: 15.px, color: C.chipText),
      );
}
