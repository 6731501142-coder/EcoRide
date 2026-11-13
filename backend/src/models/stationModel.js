const db = require('../db');

const COLS = 'station_id, name, total_docks, icon_key, photo_url, latitude, longitude, is_active';

const listActive = () => db.query(`SELECT ${COLS} FROM stations WHERE is_active = 1 ORDER BY station_id`);
const listAll = () => db.query(`SELECT ${COLS} FROM stations ORDER BY station_id`);
const findById = async (id) => (await db.query(`SELECT ${COLS} FROM stations WHERE station_id = ?`, [id]))[0] || null;

/** name already used by another station? (case-insensitive) */
const nameTaken = async (name, exceptId = 0) =>
  (await db.query('SELECT 1 FROM stations WHERE LOWER(name) = LOWER(?) AND station_id <> ? LIMIT 1', [name, exceptId])).length > 0;

async function create({ name, total_docks, icon_key = 'building' }) {
  const r = await db.query('INSERT INTO stations (name, total_docks, icon_key) VALUES (?, ?, ?)', [name, total_docks, icon_key]);
  return r.insertId;
}

const update = (id, { name, total_docks, is_active, icon_key }) =>
  db.query('UPDATE stations SET name = ?, total_docks = ?, is_active = ?, icon_key = ? WHERE station_id = ?', [
    name, total_docks, is_active ? 1 : 0, icon_key, id,
  ]);

const setPhoto = (id, photoUrl) => db.query('UPDATE stations SET photo_url = ? WHERE station_id = ?', [photoUrl, id]);

/** vehicles parked here (any status) – they occupy a dock */
const countDocked = async (id) =>
  (await db.query('SELECT COUNT(*) AS n FROM vehicles WHERE current_station_id = ?', [id]))[0].n;

/** riders who borrowed from this station and have not returned yet */
const countOpenRidesFrom = async (id) =>
  (await db.query(`SELECT COUNT(*) AS n FROM rides WHERE start_station_id = ? AND status IN ('active','overdue')`, [id]))[0].n;

module.exports = { listActive, listAll, findById, nameTaken, create, update, setPhoto, countDocked, countOpenRidesFrom };
