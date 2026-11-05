# EcoRide – Admin pages (Sprint 2)

หน้าฝั่ง Admin 3 หน้า: **Admin Dashboard**, **Manage Stations**, **Manage Vehicles**
ใช้ธีมแดง-ทองชุดเดียวกับ `frontend/home_vehicle_station` (คัดลอก `core/` และ `widgets/basic.dart`, `widgets/bars.dart` มาใช้)
ยังไม่เชื่อม backend – ใช้ข้อมูล mock ตาม SAMPLE DATA ใน `ecoride_backend_schema_v2.sql`

## วิธีรัน
```bash
cd frontend/admin_ecoride
flutter create . --platforms=web,android   # สร้างโฟลเดอร์ platform ครั้งแรกครั้งเดียว
flutter pub get
flutter run -d chrome
flutter test                                # unit test ของ AdminStore
```

## โครงสร้าง (MVC)
| ส่วน | ไฟล์ | หน้าที่ |
|---|---|---|
| Model | `lib/data/admin_models.dart` | คลาส AdminStation / AdminVehicle ชื่อฟิลด์ตรงกับตาราง DB, fromJson/toJson |
| Model/Controller | `lib/data/admin_store.dart` | CRUD + กฎตรวจสอบตาม CHECK constraint ของ DB, คำนวณ dashboard (= VIEW) |
| View | `lib/screens/*.dart` | หน้าจอ |
| View (ชิ้นส่วน) | `lib/widgets/admin_widgets.dart` | header, nav bar, ช่องกรอก, dialog ยืนยัน, toast |

## Sprint 3
เปลี่ยนเนื้อในฟังก์ชันของ `AdminStore` ให้เรียก API ผ่าน Dio (เช่น `GET /api/stations`, `POST /api/vehicles`) – หน้าจอไม่ต้องแก้
