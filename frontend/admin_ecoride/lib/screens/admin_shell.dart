// AdminShell – โครงหน้าหลักของ Admin: 3 แท็บ + เมนูล่าง
// ใช้ IndexedStack เพื่อให้แต่ละแท็บจำสถานะเดิม (คำค้นหา/ตัวกรอง) ตอนสลับไปมา
import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../widgets/admin_widgets.dart';
import 'admin_dashboard_screen.dart';
import 'manage_stations_screen.dart';
import 'manage_vehicles_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.onLogout});

  /// Sprint 3: ส่งฟังก์ชันที่ลบ JWT ออกจาก flutter_secure_storage แล้วกลับหน้า Login
  final VoidCallback? onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0; // 0 Dashboard, 1 Stations, 2 Vehicles

  void _go(int i) => setState(() => _tab = i);

  Future<void> _logout() async {
    final ok = await confirmDialog(context,
        title: 'Log out?', message: 'You will return to the login page.', ok: 'Log out');
    if (!ok || !mounted) return;
    if (widget.onLogout != null) {
      widget.onLogout!();
    } else {
      toast(context, 'Logged out (login page connects in Sprint 3)');
    }
  }

  @override
  Widget build(BuildContext context) {
    Ui.init(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            AdminDashboardScreen(onOpenTab: _go, onLogout: _logout),
            const ManageStationsScreen(),
            const ManageVehiclesScreen(),
          ],
        ),
      ),
      bottomNavigationBar: AdminNavBar(index: _tab, onTap: _go),
    );
  }
}
