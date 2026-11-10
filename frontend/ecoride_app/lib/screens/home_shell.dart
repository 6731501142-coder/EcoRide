// โครงหลักหลัง Login: 3 แท็บ Home · History · Profile + เมนูล่าง
// IndexedStack = เก็บทั้ง 3 แท็บไว้ สลับไปมาแล้วคำค้นหา/ตำแหน่งเลื่อนไม่หาย
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../core/colors.dart';
import '../core/photo_picker.dart';
import '../core/ui.dart';
import '../data/app_store.dart';
import '../data/avatars.dart';
import '../data/models.dart';
import '../widgets/bars.dart';
import '../widgets/basic.dart';
import '../widgets/station_pic.dart';
import '../widgets/form.dart';
import 'account_screens.dart';
import 'auth_screens.dart';
import 'ride_screens.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0; // 0 Home, 1 History, 2 Profile

  @override
  Widget build(BuildContext context) {
    Ui.init(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const HomeTab(),
          const HistoryTab(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: AppNavBar(index: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

// ======================================================================= หน้า 3 Home
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.me!;
        final ride = store.activeRide;
        final q = _query.toLowerCase();
        final list = store.stations.where((s) => s.name.toLowerCase().contains(q)).toList();
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            RedHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: gapped([
                  Text('Hello,', style: ts(11, color: const Color(0xFFFFE6E3))),
                  Text(me.firstName, style: ts(17, w: FontWeight.w600, color: Colors.white)),
                  Container(
                    margin: EdgeInsets.only(top: 8.px),
                    padding: EdgeInsets.symmetric(horizontal: 12.px),
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(99)),
                    child: TextField(
                      key: const Key('home_search'),
                      onChanged: (v) => setState(() => _query = v),
                      style: ts(12),
                      cursorColor: C.red,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        icon: Icon(TablerIcons.search, size: 13.px, color: C.chipText),
                        hintText: 'Search station or building',
                        hintStyle: ts(12, color: C.muted),
                        contentPadding: EdgeInsets.symmetric(vertical: 10.px),
                      ),
                    ),
                  ),
                ], h: 0),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.px, 12.px, 14.px, 14.px),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: gapped([
                  // แผงสรุป: รถพร้อมยืม · กำลังชาร์จ · จำนวนรอบเดือนนี้
                  Row(
                    children: gapped([
                      Expanded(
                          child: Kpi('${store.totalReady}', 'Ready now',
                              tone: KpiTone.green, icon: TablerIcons.bolt)),
                      Expanded(
                          child: Kpi('${store.totalCharging}', 'Charging',
                              tone: KpiTone.gold, icon: TablerIcons.plugConnected)),
                      Expanded(
                          child: Kpi('${store.monthlyStats.rides}', 'Rides this month',
                              tone: KpiTone.blue, icon: TablerIcons.chartBar)),
                    ], w: 8),
                  ),
                  // เครดิตไม่พอยืม → เตือนพร้อมลิงก์เติมเงิน
                  if (ride == null && me.creditBalance < store.defaultPlan.price)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddCreditScreen())),
                      child: Container(
                        padding: EdgeInsets.all(10.px),
                        decoration: BoxDecoration(
                            color: C.redBg, borderRadius: BorderRadius.circular(14.px)),
                        child: Row(
                          children: gapped([
                            Icon(TablerIcons.alertCircle, size: 16.px, color: C.red),
                            Expanded(
                              child: Text(
                                  'You need ${baht(store.defaultPlan.price)} to borrow. '
                                  'Tap to top up.',
                                  style: ts(11, w: FontWeight.w500, color: C.redText)),
                            ),
                          ], w: 8),
                        ),
                      ),
                    ),
                  // มีรถที่ยืมค้างอยู่ → การ์ดลัดไปหน้า Summary
                  if (ride != null) _ActiveRideBanner(ride),
                  Text('Select station', style: ts(13, w: FontWeight.w500)),
                  if (list.isEmpty) Text('No station matches "$_query"', style: muStyle),
                  for (final s in list) _StationCard(s),
                ], h: 9),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard(this.s);
  final Station s;

  @override
  Widget build(BuildContext context) {
    final a = AppStore.instance.availability(s);
    return AppCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SelectBikeScreen(station: s))),
      children: [
        // สีตามสถานะสถานี: เขียว = มีรถพร้อมหลายคัน, ทอง = เหลือน้อย, แดง = ไม่มีรถพร้อม/เต็ม
        // รูปที่แอดมินตั้งไว้ (รูปถ่าย/ไอคอน) – สีขอบ/ไอคอนตามสถานะสถานี
        StationPic(s,
            a.full || a.ready == 0 ? Tint.none : (a.ready <= 2 ? Tint.few : Tint.ready),
            size: 36),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name, style: ts(13, w: FontWeight.w500)),
              Text(
                  '${a.readyBikes} ${a.readyBikes == 1 ? 'bike' : 'bikes'} · '
                  '${a.readyScooters} ${a.readyScooters == 1 ? 'scooter' : 'scooters'} · '
                  '${a.freeDocks} free docks',
                  style: muStyle),
            ],
          ),
        ),
        Pill(a.full ? 'Full' : '${a.ready} ready', kind: a.ready == 0 ? PillKind.red : PillKind.gold),
      ],
    );
  }
}

/// การ์ด "กำลังใช้รถคันไหนอยู่" – ทำให้เด่น: พื้นแดงไล่สี, รหัสรถตัวใหญ่, แบต, เวลาคืน, ปุ่ม
class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner(this.ride);
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final v = store.vehicleById(ride.vehicleId);
    final type = store.typeOf(v);
    final overdue = ride.isOverdue;
    void open() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RideSummaryScreen()));
    return GestureDetector(
      onTap: open,
      child: Container(
        padding: EdgeInsets.all(12.px),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: overdue
                ? const [Color(0xFF8E1F27), Color(0xFFC8323C)]
                : const [C.red, Color(0xFFE0574F)],
          ),
          borderRadius: BorderRadius.circular(18.px),
          border: Border.all(color: C.gold, width: 2.px),
          boxShadow: [
            BoxShadow(
                color: C.red.withValues(alpha: 0.30),
                blurRadius: 14.px,
                offset: Offset(0, 5.px)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: gapped([
            Row(
              children: gapped([
                Container(
                  width: 42.px,
                  height: 42.px,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: C.goldBg),
                  child: Icon(type.icon, size: 22.px, color: C.red),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(overdue ? 'OVERDUE · RETURN NOW' : 'YOU ARE RIDING',
                          style: ts(10, w: FontWeight.w600, color: C.goldBg)),
                      Text(v.code, style: ts(20, w: FontWeight.w700, color: Colors.white)),
                      Text(type.name, style: ts(11, color: const Color(0xFFFFE6E3))),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.px, vertical: 3.px),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    children: [
                      Icon(TablerIcons.battery, size: 12.px, color: Colors.white),
                      SizedBox(width: 3.px),
                      Text('${store.liveBattery(v)}%',
                          style: ts(11, w: FontWeight.w500, color: Colors.white)),
                    ],
                  ),
                ),
              ], w: 10),
            ),
            Text(
              'From ${store.stationById(ride.startStationId).name} · '
              'return by ${dmy(ride.dueTime)} ${hm(ride.dueTime)}',
              style: ts(11, color: Colors.white),
            ),
            GestureDetector(
              onTap: open,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.px),
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(99)),
                child: Text('View ride & return',
                    style: ts(12, w: FontWeight.w600, color: C.ink)),
              ),
            ),
          ], h: 8),
        ),
      ),
    );
  }
}

// ======================================================================= หน้า 5 History
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final stats = store.monthlyStats;
        final rides = store.myRides;
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(14.px, 12.px, 14.px, 14.px),
            children: gapped([
              Text('History', style: ts(15, w: FontWeight.w500)),
              Row(
                children: gapped([
                  Expanded(
                      child: Kpi('${stats.rides}', 'Rides this month',
                          tone: KpiTone.blue, icon: TablerIcons.bike)),
                  Expanded(
                      child: Kpi((stats.minutes / 60).toStringAsFixed(1), 'Hours total',
                          tone: KpiTone.purple, icon: TablerIcons.clock)),
                ], w: 8),
              ),
              Text(rides.isEmpty ? 'No rides yet' : 'Tap a ride to see details', style: muStyle),
              // คั่นแต่ละเดือนด้วยชื่อเดือน + ปี
              for (final (month, items) in groupByMonth(rides, (Ride r) => r.startTime)) ...[
                MonthHeader(month),
                for (final r in items) _RideCard(r),
              ],
            ], h: 9),
          ),
        );
      },
    );
  }
}

(String, PillKind) rideBadge(Ride r) {
  if (r.isOverdue) return ('Overdue', PillKind.red);
  if (r.isOpen) return ('Riding', PillKind.solid);
  return ('Returned', PillKind.gold);
}

class _RideCard extends StatelessWidget {
  const _RideCard(this.r);
  final Ride r;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final v = store.vehicleById(r.vehicleId);
    // ยืม-คืนที่สถานีเดียวกันเสมอ → แสดงชื่อสถานีเดียวพอ
    final station = store.stationById(r.startStationId).name;
    final (badge, kind) = rideBadge(r);
    return AppCard(
      onTap: () => showRideDetail(context, r),
      children: [
        TintIc(store.typeOf(v).icon, store.typeOf(v).isBike ? Tint.bike : Tint.scooter),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${v.code} · ${dmy(r.startTime)}', style: ts(12, w: FontWeight.w500)),
              Text(station, style: muStyle),
              Text(
                  r.endTime == null
                      ? 'Started ${hm(r.startTime)}'
                      : '${hm(r.startTime)} – ${hm(r.endTime!)} · ${duration(r.usedTime)}',
                  style: muStyle),
            ],
          ),
        ),
        Pill(badge, kind: kind),
      ],
    );
  }
}

/// popup รายละเอียดการยืม 1 ครั้ง (ตาม flow: History → popup)
void showRideDetail(BuildContext context, Ride r) {
  final store = AppStore.instance;
  final v = store.vehicleById(r.vehicleId);
  final (badge, kind) = rideBadge(r);
  showModalBottomSheet<void>(
    context: context,
    // isScrollControlled + ScrollView: เนื้อหายาวกว่าจอก็เลื่อนได้ ไม่ล้น (แก้บั๊กแถบเหลืองดำ)
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
    backgroundColor: C.cream,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.px))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.px, 14.px, 16.px, 12.px),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: gapped([
            Row(
              children: gapped([
                TintIc(store.typeOf(v).icon, store.typeOf(v).isBike ? Tint.bike : Tint.scooter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.code, style: ts(14, w: FontWeight.w500)),
                      Text(store.typeOf(v).name, style: muStyle),
                    ],
                  ),
                ),
                Pill(badge, kind: kind),
              ], w: 8),
            ),
            Panel(
              child: Column(
                children: [
                  InfoRow('Borrowed', '${dmy(r.startTime)} · ${hm(r.startTime)}'),
                  InfoRow('Returned',
                      r.endTime == null ? '—' : '${dmy(r.endTime!)} · ${hm(r.endTime!)}'),
                  InfoRow('Station', store.stationById(r.startStationId).name),
                  InfoRow('Total time', duration(r.usedTime)),
                  InfoRow('Battery',
                      r.batteryEnd == null
                          ? '${r.batteryStart}% → ${store.liveBattery(v)}% (now)'
                          : '${r.batteryStart}% → ${r.batteryEnd}%'),
                  InfoRow('Paid', baht(r.pricePaid), last: true, valueColor: C.red, bold: true),
                ],
              ),
            ),
            Btn('Close', kind: BtnKind.outlined, onTap: () => Navigator.pop(ctx)),
          ], h: 10),
        ),
      ),
    ),
  );
}

// ======================================================================= หน้า 6 Profile
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  void _go(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Log out?', message: 'You will return to the login page.', ok: 'Log out');
    if (!ok || !context.mounted) return;
    AppStore.instance.logout();
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  /// ปุ่มกล้อง: เลือกอวาตาร์สำเร็จรูป (แบบ Discord) / อัปโหลดรูปเอง / ลบรูป
  Future<void> _changePhoto(BuildContext context) async {
    final store = AppStore.instance;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.cream,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.px))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.px, 14.px, 16.px, 8.px),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose an avatar', style: ts(14, w: FontWeight.w600)),
              Text('Pick one of ours, or upload your own photo', style: muStyle),
              SizedBox(height: 12.px),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10.px,
                crossAxisSpacing: 10.px,
                children: [
                  for (final a in presetAvatars)
                    GestureDetector(
                      key: Key('avatar_${a.id}'),
                      onTap: () => Navigator.pop(ctx, 'preset:${a.id}'),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: a.bg,
                          border: Border.all(
                              color: store.avatarId == a.id ? C.red : C.line,
                              width: store.avatarId == a.id ? 3.px : 1.px),
                        ),
                        child: Icon(a.icon, size: 26.px, color: a.fg),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8.px),
              if (canPickPhoto)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Ic(TablerIcons.upload),
                  title: Text('Upload your own photo', style: ts(12, w: FontWeight.w500)),
                  onTap: () => Navigator.pop(ctx, 'pick'),
                ),
              if (store.hasAvatar)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Ic(TablerIcons.trash, red: true),
                  title: Text('Remove avatar', style: ts(12, w: FontWeight.w500, color: C.red)),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null) return;
    if (action.startsWith('preset:')) {
      store.setPresetAvatar(int.parse(action.substring(7)));
      if (context.mounted) toast(context, 'Avatar updated');
    } else if (action == 'remove') {
      store.setAvatar(null);
    } else if (action == 'pick') {
      try {
        final bytes = await pickPhotoBytes();
        if (bytes == null) return; // กดยกเลิก
        if (bytes.length > 5 * 1024 * 1024) {
          if (context.mounted) toast(context, 'Please choose a photo under 5 MB', error: true);
          return;
        }
        store.setAvatar(bytes);
        if (context.mounted) toast(context, 'Profile photo updated');
      } catch (_) {
        if (context.mounted) toast(context, 'Could not open this photo', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.me;
        if (me == null) return const SizedBox.shrink(); // หลัง logout
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            RedHeader(
              padding: EdgeInsets.fromLTRB(14.px, 18.px, 14.px, 16.px),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProfileAvatar(me: me, size: 64),
                      Positioned(
                        right: -4.px,
                        bottom: -2.px,
                        child: GestureDetector(
                          onTap: () => _changePhoto(context),
                          child: Container(
                            width: 26.px,
                            height: 26.px,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: C.red, width: 1.5.px)),
                            child: Icon(TablerIcons.camera, size: 13.px, color: C.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.px),
                  Text(me.fullName, style: ts(15, w: FontWeight.w600, color: Colors.white)),
                  Text('${me.studentId} · Student',
                      style: ts(11, color: const Color(0xFFFFE6E3))),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.px, 10.px, 14.px, 14.px),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: gapped([
                  Row(
                    children: gapped([
                      Expanded(
                          child: Kpi(baht(me.creditBalance), 'Credit left',
                              tone: KpiTone.gold, icon: TablerIcons.wallet)),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _go(context, const AddCreditScreen()),
                          child: Container(
                            padding: EdgeInsets.all(8.px),
                            decoration: BoxDecoration(
                                color: C.red, borderRadius: BorderRadius.circular(16.px)),
                            child: Column(
                              children: [
                                Icon(TablerIcons.plus, size: 17.px, color: Colors.white),
                                Text('Add credit',
                                    style: ts(11, w: FontWeight.w500, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ], w: 8),
                  ),
                  // ไอคอนแต่ละเมนูคนละสี (แบบหน้าตั้งค่าของ iPhone)
                  _MenuRow(TablerIcons.receipt, 'Payment history',
                      () => _go(context, const PaymentHistoryScreen()),
                      color: const Color(0xFF34A853)),
                  _MenuRow(TablerIcons.settings, 'Account settings',
                      () => _go(context, const AccountSettingsScreen()),
                      color: const Color(0xFF8E8E93)),
                  _MenuRow(TablerIcons.messageReport, 'Report & feedback',
                      () => _go(context, const FeedbackScreen()),
                      color: const Color(0xFFFF9500)),
                  AppCard(children: [
                    const SquareIc(TablerIcons.messageCircle, Color(0xFF007AFF)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Contact us', style: ts(12, w: FontWeight.w500)),
                          Text('[CONTACT EMAIL] · [PHONE]', style: muStyle),
                        ],
                      ),
                    ),
                  ]),
                  Btn('Log out',
                      key: const Key('btn_logout'),
                      icon: TablerIcons.logout,
                      kind: BtnKind.outlined,
                      onTap: () => _logout(context)),
                ], h: 7),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, this.onTap, {required this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      children: [
        SquareIc(icon, color),
        Expanded(child: Text(label, style: ts(12, w: FontWeight.w500))),
        Icon(TablerIcons.chevronRight, size: 14.px, color: C.chipText),
      ],
    );
  }
}

/// รูปโปรไฟล์: รูปที่อัปโหลด → อวาตาร์สำเร็จรูป → ตัวอักษรย่อชื่อ (ตามลำดับ)
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.me, this.size = 58});
  final User me;
  final double size;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final bytes = store.avatarBytes;
    final preset = presetAvatarById(store.avatarId);
    return Container(
      width: size.px,
      height: size.px,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: preset?.bg ?? C.goldBg,
        border: Border.all(color: Colors.white, width: 2.px),
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      child: bytes != null
          ? null
          : preset != null
              ? Icon(preset.icon, size: (size * 0.5).px, color: preset.fg)
              : Text(me.initials, style: ts(19, w: FontWeight.w600, color: C.red)),
    );
  }
}
