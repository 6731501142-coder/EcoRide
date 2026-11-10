// เลือกรูปจากเครื่อง โดยไม่ใช้ปลั๊กอิน (เลยไม่ต้องเปิด Developer Mode ของ Windows)
// - รันบน Chrome/เว็บ → ใช้ photo_picker_web.dart (เปิดหน้าต่างเลือกไฟล์ของเบราว์เซอร์)
// - รันบนแพลตฟอร์มอื่น → ใช้ photo_picker_stub.dart (ยังไม่รองรับ)
export 'photo_picker_stub.dart' if (dart.library.js_interop) 'photo_picker_web.dart';
