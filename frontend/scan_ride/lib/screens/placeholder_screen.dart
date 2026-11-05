import 'package:flutter/material.dart';

/// หน้าจำลองสำหรับหน้าที่เพื่อนยังไม่ส่งมา (Home, Return station, Report)
/// เมื่อรวมโค้ดกับเพื่อนแล้วให้ลบไฟล์นี้ และเปลี่ยน routes ใน main.dart เป็นหน้าจริง
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const PlaceholderScreen({
    super.key,
    required this.title,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Placeholder — จะถูกแทนด้วยหน้าของเพื่อน'),
            if (buttonLabel != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 240,
                child: ElevatedButton(
                  onPressed: onPressed,
                  child: Text(buttonLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
