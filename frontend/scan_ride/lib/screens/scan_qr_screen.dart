import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../models/vehicle.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../widgets/info_tile.dart';
import '../widgets/scan_frame.dart';

/// หน้า 6 · Scan QR code
/// ลำดับการทำงาน: สแกน/กรอกรหัส -> ถามข้อมูลรถ -> แสดงการ์ดให้ตรวจ
///               -> กด Confirm borrow -> เริ่มการยืม -> ไปหน้า Active Riding
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode], // อ่านเฉพาะ QR
    detectionSpeed: DetectionSpeed.noDuplicates, // QR เดิมไม่ยิงซ้ำรัว ๆ
  );

  Vehicle? _vehicle; // รถที่สแกนเจอ
  String? _error; // ข้อความผิดพลาดที่จะแสดง
  bool _looking = false; // กำลังถาม server ว่ารถคันนี้คืออะไร
  bool _borrowing = false; // กำลังกด Confirm borrow
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose(); // ปิดกล้องเมื่อออกจากหน้า
    super.dispose();
  }

  // ---------------- การสแกน ----------------

  void _onDetect(BarcodeCapture capture) {
    if (_looking || _borrowing || _vehicle != null) return;
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw != null && raw.isNotEmpty) _lookup(raw);
  }

  /// เอาข้อความจาก QR (หรือที่พิมพ์เอง) ไปถามข้อมูลรถ
  Future<void> _lookup(String raw) async {
    setState(() {
      _looking = true;
      _error = null;
    });
    try {
      final vehicle =
          await ApiService.instance.getVehicle(Vehicle.codeFromQr(raw));
      if (!mounted) return;
      setState(() {
        _vehicle = vehicle;
        _error = vehicle.blockReason; // null ถ้ายืมได้
      });
      try {
        await _controller.stop(); // เจอรถแล้ว หยุดกล้อง ประหยัดแบต
      } catch (_) {}
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Cannot reach the server. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _vehicle = null;
      _error = null;
    });
    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available on this device.')),
      );
    }
  }

  /// กรอกรหัสเอง: ใช้เมื่อกล้องไม่ได้ / QR เสีย / ทดสอบบนคอมที่ไม่มีกล้อง
  Future<void> _manualEntry() async {
    final input = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter vehicle code'),
        content: TextField(
          controller: input,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. EB-012'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, input.text),
              child: const Text('Find')),
        ],
      ),
    );
    input.dispose();
    if (code != null && code.trim().isNotEmpty) _lookup(code);
  }

  // ---------------- ยืนยันการยืม ----------------

  Future<void> _confirmBorrow() async {
    final vehicle = _vehicle;
    if (_borrowing || vehicle == null || !vehicle.canBorrow) return;

    setState(() {
      _borrowing = true;
      _error = null;
    });
    try {
      final ride = await ApiService.instance.startRide(vehicle);
      if (!mounted) return;
      context.read<RideProvider>().startRide(ride); // เก็บสถานะ + เริ่มจับเวลา
      Navigator.pushReplacementNamed(context, AppRoutes.riding);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Cannot reach the server. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _borrowing = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scanBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              torchOn: _torchOn,
              onClose: () => Navigator.maybePop(context),
              onTorch: _toggleTorch,
            ),
            Expanded(child: _buildScanner()),
            _BorrowSheet(
              vehicle: _vehicle,
              error: _error,
              looking: _looking,
              borrowing: _borrowing,
              onConfirm: _confirmBorrow,
              onScanAgain: _scanAgain,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScanFrame(
          // ฟังสถานะกล้อง: ถ้ากล้องยังไม่พร้อม/ถูกหยุด/ผิดพลาด ให้โชว์ไอคอน QR แทน
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final cameraReady = state.isRunning && state.error == null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(controller: _controller, onDetect: _onDetect),
                  if (!cameraReady)
                    _QrPlaceholder(
                      message: state.error != null ? 'Camera unavailable' : null,
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Align the QR code on the vehicle',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _manualEntry,
          child: const Text('Enter code manually',
              style: TextStyle(color: AppColors.gold)),
        ),
      ],
    );
  }
}

/// แถบบน: ปิด / ชื่อหน้า / แฟลช
class _TopBar extends StatelessWidget {
  final bool torchOn;
  final VoidCallback onClose;
  final VoidCallback onTorch;

  const _TopBar({
    required this.torchOn,
    required this.onClose,
    required this.onTorch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Scan QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Flash',
            onPressed: onTorch,
            icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off,
                color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

/// ไอคอน QR สีทอง (ใช้ตอนกล้องยังไม่พร้อม — เหมือนในแบบ UI)
class _QrPlaceholder extends StatelessWidget {
  final String? message;

  const _QrPlaceholder({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2E1E1E),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_2, size: 110, color: AppColors.gold),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// แผงด้านล่าง: การ์ดข้อมูลรถ + ปุ่ม Confirm borrow
class _BorrowSheet extends StatelessWidget {
  final Vehicle? vehicle;
  final String? error;
  final bool looking;
  final bool borrowing;
  final VoidCallback onConfirm;
  final VoidCallback onScanAgain;

  const _BorrowSheet({
    required this.vehicle,
    required this.error,
    required this.looking,
    required this.borrowing,
    required this.onConfirm,
    required this.onScanAgain,
  });

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final canConfirm = v != null && v.canBorrow; // ปุ่มกดได้เมื่อสแกนแล้วและยืมได้

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (v == null)
            InfoTile(
              icon: Icons.qr_code_scanner,
              title: looking ? 'Looking up vehicle…' : 'Waiting for QR code',
              subtitle: 'Scan the code on the handlebar',
            )
          else
            InfoTile(
              icon: v.type == VehicleType.ebike
                  ? Icons.directions_bike
                  : Icons.electric_scooter,
              title: '${v.id} · ${v.typeLabel}',
              subtitle: 'Battery ${v.battery}% · ${v.stationName}',
              trailing: StatusChip(
                label: v.canBorrow ? 'Ready' : 'Unavailable',
                positive: v.canBorrow,
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.crimson,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: canConfirm ? onConfirm : null,
            child: borrowing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm borrow'),
          ),
          if (v != null)
            TextButton(
              onPressed: borrowing ? null : onScanAgain,
              child: const Text('Scan another vehicle'),
            ),
        ],
      ),
    );
  }
}
