const db = require('../db');

// rides + names (same columns as VIEW v_ride_history, plus battery columns the app needs)
const SELECT = `
  SELECT r.ride_id, r.user_id, r.vehicle_id, r.plan_id, r.start_station_id, r.return_station_id,
         r.start_time, r.due_time, r.end_time, r.battery_start, r.battery_end, r.price_paid, r.status,
         v.vehicle_code, vt.code_prefix, vt.name AS vehicle_type,
         ss.name AS from_station, rs.name AS return_station,
         TIMESTAMPDIFF(MINUTE, r.start_time, COALESCE(r.end_time, NOW())) AS duration_min,
         (r.status = 'overdue' OR (r.status = 'active' AND r.due_time < NOW())) AS is_overdue
  FROM rides r
  JOIN vehicles v ON v.vehicle_id = r.vehicle_id
  JOIN vehicle_types vt ON vt.type_id = v.type_id
  JOIN stations ss ON ss.station_id = r.start_station_id
  LEFT JOIN stations rs ON rs.station_id = r.return_station_id`;

const OPEN = `r.status IN ('active','overdue')`;

const findById = async (id) => (await db.query(`${SELECT} WHERE r.ride_id = ?`, [id]))[0] || null;
const findOpenByUser = async (userId) =>
  (await db.query(`${SELECT} WHERE r.user_id = ? AND ${OPEN} ORDER BY r.start_time DESC LIMIT 1`, [userId]))[0] || null;
const listByUser = (userId) => db.query(`${SELECT} WHERE r.user_id = ? ORDER BY r.start_time DESC`, [userId]);
const listAll = () => db.query(`${SELECT} ORDER BY r.start_time DESC`);
/** overdue first, then the one due soonest (AppStore.openRides) */
const listOpen = () => db.query(`${SELECT} WHERE ${OPEN} ORDER BY is_overdue DESC, r.due_time ASC`);

/** this month's numbers for one student = VIEW v_user_monthly_stats */
const monthlyStats = async (userId) =>
  (await db.query('SELECT user_id, rides_this_month, hours_total, spent_this_month FROM v_user_monthly_stats WHERE user_id = ?', [userId]))[0] ||
  { user_id: userId, rides_this_month: 0, hours_total: 0, spent_this_month: 0 };

/** sp_borrow_vehicle(user, vehicle, plan, @ride_id) -> new ride_id. Throws the procedure's error message. */
const callBorrow = (userId, vehicleId, planId) =>
  db.withConnection(async (conn) => {
    await conn.query('CALL sp_borrow_vehicle(?, ?, ?, @ride_id)', [userId, vehicleId, planId]);
    const [rows] = await conn.query('SELECT @ride_id AS ride_id');
    return rows[0].ride_id;
  });

/** sp_return_vehicle(ride, station, battery_end) */
const callReturn = (rideId, stationId, batteryEnd) =>
  db.withConnection((conn) => conn.query('CALL sp_return_vehicle(?, ?, ?)', [rideId, stationId, batteryEnd]));

module.exports = { findById, findOpenByUser, listByUser, listAll, listOpen, monthlyStats, callBorrow, callReturn };
