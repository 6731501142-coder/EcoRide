const db = require('../db');

// One SELECT used everywhere. Besides the vehicle columns it returns what batteryService needs:
//  seconds_since_battery_update (charging while parked) and, if someone is riding it,
//  ride_battery_start / ride_used_seconds (discharging while riding).
const SELECT = `
  SELECT v.vehicle_id, v.vehicle_code, v.type_id, v.current_station_id, v.battery_level,
         v.battery_updated_at, v.status,
         vt.code_prefix, vt.name AS type_name, s.name AS station_name,
         TIMESTAMPDIFF(SECOND, v.battery_updated_at, NOW()) AS seconds_since_battery_update,
         r.ride_id AS open_ride_id, r.battery_start AS ride_battery_start,
         TIMESTAMPDIFF(SECOND, r.start_time, NOW()) AS ride_used_seconds
  FROM vehicles v
  JOIN vehicle_types vt ON vt.type_id = v.type_id
  LEFT JOIN stations s ON s.station_id = v.current_station_id
  LEFT JOIN rides r ON r.vehicle_id = v.vehicle_id AND r.status IN ('active','overdue')`;

const findById = async (id) => (await db.query(`${SELECT} WHERE v.vehicle_id = ?`, [id]))[0] || null;

const findByCode = async (code) =>
  (await db.query(`${SELECT} WHERE UPPER(v.vehicle_code) = UPPER(?)`, [String(code).trim()]))[0] || null;

const listAll = () => db.query(`${SELECT} ORDER BY v.vehicle_code`);
const listAtStation = (stationId) => db.query(`${SELECT} WHERE v.current_station_id = ?`, [stationId]);
const listDocked = () => db.query(`${SELECT} WHERE v.current_station_id IS NOT NULL`);

const codeExists = async (code) =>
  (await db.query('SELECT 1 FROM vehicles WHERE vehicle_code = ? LIMIT 1', [code])).length > 0;

async function create({ vehicle_code, type_id, station_id }) {
  const r = await db.query(
    `INSERT INTO vehicles (vehicle_code, type_id, current_station_id, battery_level, status)
     VALUES (?, ?, ?, 100, 'available')`,
    [vehicle_code, type_id, station_id]
  );
  return r.insertId;
}

/** save the battery that batteryService worked out, and restart the "charging since" clock */
const saveBattery = (id, level) =>
  db.query('UPDATE vehicles SET battery_level = ?, battery_updated_at = NOW() WHERE vehicle_id = ?', [level, id]);

/** send to repair: keep the battery as it is now; back to service: charging starts again */
const setMaintenance = (id, repair, level) =>
  repair
    ? db.query(`UPDATE vehicles SET status = 'maintenance', battery_level = ?, battery_updated_at = NOW() WHERE vehicle_id = ?`, [level, id])
    : db.query(`UPDATE vehicles SET status = 'available', battery_updated_at = NOW() WHERE vehicle_id = ?`, [id]);

module.exports = { findById, findByCode, listAll, listAtStation, listDocked, codeExists, create, saveBattery, setMaintenance };
