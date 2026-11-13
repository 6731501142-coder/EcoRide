const app = require('./app');
const config = require('./config');
const db = require('./db');
const crypto = require('crypto');

async function main() {
  // ไม่ยอมรันถ้า JWT_SECRET ไม่ปลอดภัย (กันคนปลอม token เป็น admin)
  const problem = config.jwtSecretProblem(config.jwtSecret);
  if (problem) {
    console.error(`Cannot start: ${problem}.`);
    console.error('Open backend/.env and set JWT_SECRET to a long random text, for example:');
    console.error(`JWT_SECRET=${crypto.randomBytes(32).toString('hex')}`);
    process.exit(1);
  }

  try {
    await db.query('SELECT 1'); // fail early (and clearly) if the database is not reachable
  } catch (e) {
    console.error(`Cannot connect to MariaDB at ${config.db.host}:${config.db.port} (database "${config.db.database}")`);
    console.error(`-> ${e.message}`);
    console.error('Start MariaDB (XAMPP), import ecoride_db.sql, and check the DB_* values in .env');
    process.exit(1);
  }
  app.listen(config.port, () => console.log(`EcoRide API running on http://localhost:${config.port}/api`));
}

main();
