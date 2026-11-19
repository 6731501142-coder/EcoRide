// problem_reports (Need help? button + issues the admin works on)
const db = require('../db');

const SELECT = `SELECT p.report_id, p.user_id, p.vehicle_id, p.ride_id, p.category, p.is_urgent, p.location,
  p.details, p.status, p.created_at, p.resolved_at,
  v.vehicle_code, u.full_name AS user_name
  FROM problem_reports p
  JOIN vehicles v ON v.vehicle_id = p.vehicle_id
  JOIN users u ON u.user_id = p.user_id`;

// is_urgent is TINYINT(1) -> real true / false in the JSON
const fix = (r) => (r ? { ...r, is_urgent: !!r.is_urgent } : r);

const findById = async (id) => fix((await db.query(`${SELECT} WHERE p.report_id = ?`, [id]))[0] || null);
const listAll = async () => (await db.query(`${SELECT} ORDER BY p.created_at DESC, p.report_id DESC`)).map(fix);

async function create({ user_id, vehicle_id, ride_id = null, category, is_urgent = false, location = null, details = null }) {
  const r = await db.query(
    `INSERT INTO problem_reports (user_id, vehicle_id, ride_id, category, is_urgent, location, details)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [user_id, vehicle_id, ride_id, category, is_urgent ? 1 : 0, location, details]
  );
  return r.insertId;
}

/** resolved -> resolved_at = now, anything else -> resolved_at cleared (AppStore.setReportStatus) */
const setStatus = (id, status) =>
  db.query(`UPDATE problem_reports SET status = ?, resolved_at = IF(? = 'resolved', NOW(), NULL) WHERE report_id = ?`, [
    status, status, id,
  ]);

module.exports = { findById, listAll, create, setStatus };
