require('dotenv').config({ quiet: true });

const num = (v, d) => (v === undefined || v === '' || Number.isNaN(Number(v)) ? d : Number(v));

// ---- JWT secret -------------------------------------------------------------
// ใครรู้ค่านี้ = ปลอม token เป็นใครก็ได้ (รวมถึง admin) จึงห้ามใช้ค่าตั้งต้น / ค่าตัวอย่าง / ค่าสั้นๆ
// ตอนรัน `npm test` (NODE_ENV=test) ใช้ค่าสำหรับเทสต์ได้ เพราะเทสต์ไม่ได้รัน server จริง
const PLACEHOLDER_SECRETS = ['dev-secret-change-me', 'change-me-to-a-long-random-text'];
const MIN_SECRET_LENGTH = 32;
const isTest = process.env.NODE_ENV === 'test';

/** คืนข้อความบอกปัญหาของ JWT_SECRET หรือ null ถ้าใช้ได้ */
function jwtSecretProblem(secret) {
  const s = String(secret ?? '');
  if (!s) return 'JWT_SECRET is not set';
  if (PLACEHOLDER_SECRETS.includes(s)) return 'JWT_SECRET is still the example value';
  if (s.length < MIN_SECRET_LENGTH) return `JWT_SECRET is too short (needs at least ${MIN_SECRET_LENGTH} characters)`;
  return null;
}

module.exports = {
  jwtSecretProblem,
  MIN_SECRET_LENGTH,
  port: num(process.env.PORT, 3000),
  db: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: num(process.env.DB_PORT, 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'ecoride_db',
  },
  jwtSecret: process.env.JWT_SECRET || (isTest ? 'test-only-secret-not-for-real-use-0123456789' : ''),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  corsOrigin: process.env.CORS_ORIGIN || '*',

  // business rules (same numbers as AppStore in the Flutter app)
  minBattery: 20, // lowest battery % that can be borrowed
  minTopup: 20,
  maxTopup: 5000,
  timeScale: num(process.env.BATTERY_TIME_SCALE, 1),
  allowSelfConfirmTopup: process.env.ALLOW_SELF_CONFIRM_TOPUP !== 'false',

  uploadDir: process.env.UPLOAD_DIR || require('path').join(__dirname, '..', 'uploads'),
  maxImageBytes: 2 * 1024 * 1024,
};
