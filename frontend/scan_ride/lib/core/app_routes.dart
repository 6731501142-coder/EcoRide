/// ชื่อเส้นทาง (route) ของทุกหน้า — เป็น "ข้อตกลงกลาง" ระหว่างเพื่อนในทีม
/// ใครทำหน้าไหนให้ลงทะเบียนชื่อนี้ใน main.dart แล้วหน้าอื่น pushNamed มาหาได้เลย
class AppRoutes {
  AppRoutes._();

  static const home = '/home'; //                    หน้า 3  Home / Station list
  static const scan = '/scan'; //                    หน้า 6  Scan QR code   <- ของฉัน
  static const riding = '/riding'; //                หน้า 7  Active Riding  <- ของฉัน
  static const returnStation = '/return-station'; // หน้า 8  Choose return station
  static const report = '/report'; //                หน้า 10 Report a problem
}
