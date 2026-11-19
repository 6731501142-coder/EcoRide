// Login / register / forgot username / reset password   (= "auth" part of AppStore)
const userModel = require('../models/userModel');
const password = require('../utils/password');
const token = require('../utils/token');
const { badRequest, unauthorized, forbidden, conflict, notFound, mapDbError } = require('../utils/errors');
const { str, withBools } = require('../utils/helpers');

const BOOLS = ['is_active'];
const publicUser = (u) => {
  if (!u) return u;
  const { password_hash, ...rest } = u; // eslint-disable-line no-unused-vars
  return withBools(rest, BOOLS);
};

/** POST /auth/login  { username, password } -> { token, user } (admins use the same login) */
async function login(req, res) {
  const username = str(req.body?.username);
  const user = username ? await userModel.findByUsernameWithHash(username) : null;
  const ok = user && (await password.verify(req.body?.password, user.password_hash));
  if (!ok) throw unauthorized('Wrong username or password');
  if (!user.is_active) throw forbidden('This account has been disabled');
  if (password.needsRehash(user.password_hash)) {
    // old bcrypt hash (from the SQL file) -> upgrade to argon2id now that we know the password; never block login
    try { await userModel.updatePassword(user.user_id, await password.hash(req.body.password)); } catch { /* ignore */ }
  }
  res.json({ token: token.sign(user), user: publicUser(user) });
}

/** POST /auth/register  { full_name, student_id, username, password, confirm } */
async function register(req, res) {
  const b = req.body || {};
  const fullName = str(b.full_name);
  const studentId = str(b.student_id);
  const username = str(b.username);

  if ([fullName, studentId, username, b.password].some((s) => !str(s))) throw badRequest('Please fill in every field');
  if (fullName.length > 100) throw badRequest('Full name is too long (max 100 characters)');
  if (studentId.length > 20) throw badRequest('Student ID is too long (max 20 characters)');
  if (username.length > 50) throw badRequest('Username is too long (max 50 characters)');
  const pwErr = password.checkNewPassword(b.password, b.confirm);
  if (pwErr) throw badRequest(pwErr);
  if (await userModel.usernameTaken(username)) throw conflict('Username is already taken');
  if (await userModel.studentIdTaken(studentId)) throw conflict('Student ID is already registered');

  try {
    const id = await userModel.create({
      student_id: studentId,
      username,
      full_name: fullName,
      password_hash: await password.hash(b.password),
    });
    res.status(201).json({ user: publicUser(await userModel.findById(id)) });
  } catch (e) {
    throw mapDbError(e);
  }
}

/** POST /auth/find-username  { student_id, full_name } -> { username } */
async function findUsername(req, res) {
  const studentId = str(req.body?.student_id);
  const fullName = str(req.body?.full_name);
  if (!studentId || !fullName) throw badRequest('Please fill in every field');
  const u = await userModel.findByStudentId(studentId);
  if (!u || u.full_name.toLowerCase() !== fullName.toLowerCase()) {
    throw notFound('No account matches this student ID and name');
  }
  res.json({ username: u.username });
}

/** POST /auth/reset-password  { username, student_id, full_name, password, confirm } */
async function resetPassword(req, res) {
  const b = req.body || {};
  const username = str(b.username);
  const studentId = str(b.student_id);
  const fullName = str(b.full_name);
  if (!username || !studentId || !fullName) throw badRequest('Please fill in every field');

  const u = await userModel.findByUsername(username);
  if (!u || u.student_id !== studentId || u.full_name.toLowerCase() !== fullName.toLowerCase()) {
    throw badRequest('Username, student ID and full name do not match');
  }
  const pwErr = password.checkNewPassword(b.password, b.confirm);
  if (pwErr) throw badRequest(pwErr);

  await userModel.updatePassword(u.user_id, await password.hash(b.password));
  res.json({ ok: true });
}

module.exports = { login, register, findUsername, resetPassword, publicUser };
