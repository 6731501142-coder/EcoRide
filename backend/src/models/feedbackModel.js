// app_feedback (Report & feedback in Profile)
const db = require('../db');

const SELECT = `SELECT f.feedback_id, f.user_id, f.topic, f.message, f.status, f.created_at, u.full_name AS user_name
  FROM app_feedback f JOIN users u ON u.user_id = f.user_id`;

const findById = async (id) => (await db.query(`${SELECT} WHERE f.feedback_id = ?`, [id]))[0] || null;
const listAll = () => db.query(`${SELECT} ORDER BY f.created_at DESC, f.feedback_id DESC`);

async function create({ user_id, topic, message }) {
  const r = await db.query('INSERT INTO app_feedback (user_id, topic, message) VALUES (?, ?, ?)', [user_id, topic, message]);
  return r.insertId;
}

const setStatus = (id, status) => db.query('UPDATE app_feedback SET status = ? WHERE feedback_id = ?', [status, id]);
const countOpen = async () => (await db.query(`SELECT COUNT(*) AS n FROM app_feedback WHERE status = 'open'`))[0].n;

module.exports = { findById, listAll, create, setStatus, countOpen };
