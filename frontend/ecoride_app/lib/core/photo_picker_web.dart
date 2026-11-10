import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const bool canPickPhoto = true;

/// เปิดหน้าต่างเลือกไฟล์รูปของเบราว์เซอร์ → คืน bytes ของรูป หรือ null ถ้ากดยกเลิก
Future<Uint8List?> pickPhotoBytes() {
  final done = Completer<Uint8List?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';

  void finish(Uint8List? bytes) {
    if (!done.isCompleted) done.complete(bytes);
  }

  Future<void> read() async {
    final file = input.files?.item(0);
    if (file == null) return finish(null);
    final buffer = await file.arrayBuffer().toDart;
    finish(buffer.toDart.asUint8List());
  }

  input.addEventListener(
      'change',
      ((web.Event _) {
        read();
      }).toJS);
  input.addEventListener(
      'cancel',
      ((web.Event _) {
        finish(null);
      }).toJS);
  input.click();
  return done.future;
}
