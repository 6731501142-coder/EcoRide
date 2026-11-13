const db = require('../db');

// never select password_hash unless it is really needed
const PUBLIC = `user_id, student_id, username, full_name, avatar_id, avatar_url, role,
  credit_balance, is_active, created_at, updated_at`;

const findById = async (id) => (await db.query(`SELECT ${PUBLIC} FROM users WHERE user_id = ?`, [id]))[0] || null;

/** case-insensitive, includes password_hash (login only) */
const findByUsernameWithHash = async (username) =>
  (await db.query('SELECT * FROM users WHERE LOWER(username) = LOWER(?)', [username]))[0] || null;

const findByUsername = async (username) =>
  (await db.query(`SELECT ${PUBLIC} FROM users WHERE LOWER(username) = LOWER(?)`, [username]))[0] || null;

const findByStudentId = async (studentId) =>
  (await db.query(`SELECT ${PUBLIC} FROM users WHERE student_id = ?`, [studentId]))[0] || null;

const getPasswordHash = async (id) =>
  (await db.query('SELECT password_hash FROM users WHERE user_id = ?', [id]))[0]?.password_hash ?? null;

const usernameTaken = async (username, exceptId = 0) =>
  (await db.query('SELECT 1 FROM users WHERE LOWER(username) = LOWER(?) AND user_id <> ? LIMIT 1', [username, exceptId])).length > 0;

const studentIdTaken = async (studentId, exceptId = 0) =>
  (await db.query('SELECT 1 FROM users WHERE student_id = ? AND user_id <> ? LIMIT 1', [studentId, exceptId])).length > 0;

async function create({ student_id, username, full_name, password_hash }) {
  const r = await db.query(
    `INSERT INTO users (student_id, username, full_name, password_hash, role, credit_balance)
     VALUES (?, ?, ?, ?, 'student', 0)`,
    [student_id, username, full_name, password_hash]
  );
  return r.insertId;
}

const updateProfile = (id, { full_name, student_id, username }) =>
  db.query('UPDATE users SET full_name = ?, student_id = ?, username = ? WHERE user_id = ?', [full_name, student_id, username, id]);

/** admin edit: name + student id only (username is used to log in, so it stays) */
const updateNames = (id, { full_name, student_id }) =>
  db.query('UPDATE users SET full_name = ?, student_id = ? WHERE user_id = ?', [full_name, student_id, id]);

const updatePassword = (id, passwordHash) =>
  db.query('UPDATE users SET password_hash = ? WHERE user_id = ?', [passwordHash, id]);

/** only one kind at a time: a preset id OR an uploaded photo (the app does the same) */
const setAvatar = (id, { avatar_id = null, avatar_url = null }) =>
  db.query('UPDATE users SET avatar_id = ?, avatar_url = ? WHERE user_id = ?', [avatar_id, avatar_url, id]);

const setActive = (id, active) => db.query('UPDATE users SET is_active = ? WHERE user_id = ?', [active ? 1 : 0, id]);

/** admin Users tab: students only, optional search on name / username / student id */
async function listStudents(q = '') {
  const term = String(q).trim();
  const like = `%${term.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
  const where = term ? `AND (full_name LIKE ? OR username LIKE ? OR student_id LIKE ?)` : '';
  const params = term ? [like, like, like] : [];
  return db.query(
    `SELECT ${PUBLIC},
       EXISTS(SELECT 1 FROM rides r WHERE r.user_id = users.user_id AND r.status IN ('active','overdue')) AS riding
     FROM users WHERE role = 'student' ${where} ORDER BY full_name`,
    params
  );
}

module.exports = {
  findById, findByUsernameWithHash, findByUsername, findByStudentId, getPasswordHash,
  usernameTaken, studentIdTaken, create, updateProfile, updateNames, updatePassword,
  setAvatar, setActive, listStudents,
};
