// MariaDB connection pool.
// dateStrings: true  -> datetime columns come back as "2026-11-10 17:49:44" (no timezone),
//                       which is exactly what Dart's DateTime.parse() in the app expects.
// decimalNumbers: true -> DECIMAL columns (credit, price) come back as numbers, not strings.
const mysql = require('mysql2/promise');
const config = require('./config');

let pool;

function getPool() {
  if (!pool) {
    pool = mysql.createPool({
      ...config.db,
      waitForConnections: true,
      connectionLimit: 10,
      dateStrings: true,
      decimalNumbers: true,
      charset: 'utf8mb4',
    });
  }
  return pool;
}

/** Run one query, return the rows (or the result header for INSERT/UPDATE). */
async function query(sql, params = []) {
  const [rows] = await getPool().query(sql, params);
  return rows;
}

/** Borrow one connection (needed for CALL ... OUT parameters with @variables). */
async function withConnection(fn) {
  const conn = await getPool().getConnection();
  try {
    return await fn(conn);
  } finally {
    conn.release();
  }
}

async function close() {
  if (pool) await pool.end();
  pool = undefined;
}

module.exports = { query, withConnection, close, getPool };
