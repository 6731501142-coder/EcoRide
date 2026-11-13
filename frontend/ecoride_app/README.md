# EcoRide – แอปฝั่งผู้ใช้ (ecoride_app)

แอป Flutter ตาม flow ใน *Untitled Draft 2.pdf* และตารางใน *EcoRide – Database Summary.pdf*
ตอนนี้ **เชื่อมกับ backend แล้ว** (`../../backend`, Node.js + MariaDB): `lib/data/api_client.dart` เรียก REST API
และ `lib/data/app_store.dart` เก็บสำเนาข้อมูลล่าสุดไว้ — ดูวิธีรันทั้งโปรเจกต์ใน `../../README.md`

## วิธีรัน
```
# เปิด backend ก่อน (ดู ../../README.md) แล้ว
cd frontend/ecoride_app
flutter pub get
flutter run -d chrome        # ใช้ backend ที่ http://localhost:3000
# หรือ: flutter run -d chrome --dart-define=API_BASE=http://<ip>:3000
```
บัญชีทดลอง (ล็อกอินหน้าเดียวกัน แอปดู `users.role` แล้วพาไปหน้าที่ถูกต้อง):
- นักศึกษา: `somchai.j` / `password123` → หน้า Home
- แอดมิน: `admin` / `password123` → หน้า Admin (Overview, Stations, Vehicles, Reports, Users)

ทั้งสองฝั่งใช้ฐานข้อมูลชุดเดียวกัน → ผู้ใช้กด Need help? / ยืมรถ / เติมเงิน / ส่ง feedback แล้ว
แอดมินเห็นหลังแอป refresh (ทุก 60 วินาที หรือหลังกดอะไรสักอย่าง)

## หน้าจอ
| ไฟล์ | หน้า |
|---|---|
| `screens/auth_screens.dart` | Login, Create account, Reset password |
| `screens/home_shell.dart` | Home (เลือกสถานี), History (+ popup รายละเอียด), Profile |
| `screens/ride_screens.dart` | Select bike, Vehicle detail, Payment confirm, Summary, Return station |
| `screens/account_screens.dart` | Account settings, Report & feedback, Add credit, Payment history |
| `screens/help_screen.dart` | Need help? (เรียกเจ้าหน้าที่ระหว่างขี่) |
| `admin/` | หน้า Admin ทั้งหมด (ปรับจากแบบของเพื่อน) |

## ฟังก์ชันใน AppStore ↔ ฐานข้อมูล
| AppStore | ฐานข้อมูล |
|---|---|
| `borrow()` | `sp_borrow_vehicle` (1 คันต่อคน, แบต ≥ 20%, เครดิตพอ, หักเงิน + ลง `credit_transactions`, คืนภายใน 24 ชม.) |
| `returnVehicle()` | `sp_return_vehicle` (คืนได้เฉพาะสถานีที่ยืม และต้องมีช่องว่าง) |
| `createTopup()` + `confirmTopup()` | `topups` + `sp_confirm_topup` |
| `requestHelp()` (ปุ่ม Need help? หน้า Summary) | `problem_reports` ผูก `ride_id` + ข้อความ `[URGENT]` |
| `submitFeedback()` (Report & feedback หน้า Profile) | ⚠️ ยังไม่มีตาราง เสนอ `app_feedback` |
| `availability()` | `v_station_availability` |
| `myRides` | `v_ride_history` |
| `monthlyStats` | `v_user_monthly_stats` |

## ตรงกับ ecoride_db.sql แล้ว
- ทุก model ใน `lib/data/models.dart` ใช้ชื่อคอลัมน์จริงจาก `ecoride_db.sql` และมี `fromJson` รับแถวจาก DB/API ได้ทันที
- ข้อมูลตัวอย่างใน `AppStore._seed()` คัดลอกจาก dump ชุดเดียวกัน (3 สถานี, 10 คัน, ride 4 รอบ, top-up 3 ครั้ง, เครดิต ฿150)
- บัญชี `admin` (role = admin) ล็อกอินแอปนี้ไม่ได้ ต้องใช้แอป Admin
- แบตจำลอง (ดูรายละเอียดใน `AppStore.specOf`):
  - ขี่: ลดตามระยะทางโดยประมาณ (ชม.แรกวิ่งจริง 60%, หลังจากนั้น 10%) × %/กม. — E-bike 12 กม./ชม. 1.5%/กม., Scooter 15 กม./ชม. 3%/กม.
  - จอด: ชาร์จทุกช่อง เร็วถึง 80% แล้วช้าลง — E-bike 0→80% 3.5 ชม., Scooter 2.5 ชม., 80→100% อีก 1.5 ชม.
  - เดโมเร็วขึ้น: แก้ `AppStore.timeScale` (เช่น 30)
  - ของจริงควรได้ค่าจากตัวรถ (IoT); ตอนคืนส่งค่าที่ประมาณได้เป็น `battery_end` ให้ `sp_return_vehicle`
- Hours total รวมเวลาของรอบที่กำลังขี่อยู่ด้วย (view `v_user_monthly_stats` นับเฉพาะรอบที่คืนแล้ว)
- รูปโปรไฟล์: เลือกได้เมื่อรันบน Chrome (ไม่ใช้ปลั๊กอิน จึงไม่ต้องเปิด Developer Mode) ตอนนี้เก็บไว้ในหน่วยความจำ รีเฟรชแล้วหาย เพราะ DB ยังไม่มีคอลัมน์เก็บรูป ถ้าจะเก็บจริงต้องเพิ่ม `users.avatar_url` + API อัปโหลดรูป
- Reset password ต้องกรอก username + student ID + full name ให้ตรงกัน, ลืม username หาได้จาก student ID + full name
- อวาตาร์สำเร็จรูป 16 แบบ (`lib/data/avatars.dart`) เลือกได้ทุกแพลตฟอร์ม ถ้าจะเก็บลง DB แนะนำเพิ่ม `users.avatar_id TINYINT NULL` เก็บแค่เลข 1–16
- เติมเงินได้ครั้งละ ฿20 – ฿5,000 (กันพิมพ์ตัวเลขยาวเกิน DECIMAL(10,2))
- เบอร์เจ้าหน้าที่แก้ที่ `staffPhone` ใน `lib/screens/help_screen.dart`
- Account settings: ชื่อ, รหัสนักศึกษา, username แสดงอย่างเดียว แก้ได้แค่รหัสผ่าน
- ข้อมูลที่ติด ★ ใน `_seed()` เพิ่มเพื่อเดโมหน้า admin (ผู้ใช้ Malee/Krittin, รถที่กำลังยืม, ยืมเกินเวลา, Need help?, top-up รอยืนยัน, feedback)
- รูปสถานี: แอดมินเลือกไอคอน 9 แบบ หรืออัปโหลดรูปถ่าย (บน Chrome) ผู้ใช้เห็นในหน้า Home และหน้าเลือกรถ — เสนอเพิ่มคอลัมน์ `stations.icon_key`, `stations.photo_url`
- ปุ่ม filter ใช้ Wrap (ขึ้นบรรทัดใหม่เอง) และลากเลื่อนด้วยเมาส์ได้ทั้งแอป
