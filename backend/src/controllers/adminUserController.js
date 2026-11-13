// Admin > Users  (= students / updateUser / setUserActive / adjustCredit in AppStore)
const userModel = require('../models/userModel');
const rideModel = require('../models/rideModel');
const creditModel = require('../models/creditModel');
const { withLabel } = require('./creditController');
const { publicUser } = require('./authController');
const { badRequest, notFound, forbidden, conflict, mapDbError } = require('../utils/errors');
const { str, toInt, bool } = require('../utils/helpers');

const row = (u) => ({ ...publicUser(u), riding: !!u.riding });

/** the user must exist and be a student (admin accounts are not edited from this tab) */
async function getStudent(req) {
  const id = toInt(req.params.id);
  const u = id === null ? null : await userModel.findById(id);
  if (!u) throw notFound('User not found');
  if (u.role !== 'student') throw forbidden('Admin accounts cannot be changed here');
  return u;
}

/** GET /admin/users?q=  search name / username / student id */
async function list(req, res) {
  res.json((await userModel.listStudents(str(req.query.q))).map(row));
}

/** GET /admin/users/:id -> { user, rides, transactions } (the user detail screen) */
async function detail(req, res) {
  const u = await getStudent(req);
  const [rides, txns] = await Promise.all([rideModel.listByUser(u.user_id), creditModel.listByUser(u.user_id)]);
  res.json({
    user: publicUser(u),
    rides: rides.map((r) => ({ ...r, is_overdue: !!r.is_overdue })),
    transactions: txns.map(withLabel),
  });
}

/** PUT /admin/users/:id  { full_name, student_id } */
async function update(req, res) {
  const u = await getStudent(req);
  const fullName = str(req.body?.full_name);
  const studentId = str(req.body?.student_id);
  if (!fullName || !studentId) throw badRequest('Please fill in every field');
  if (fullName.length > 100 || studentId.length > 20) throw badRequest('Text is too long');
  if (await userModel.studentIdTaken(studentId, u.user_id)) throw conflict('This student ID is already used');
  try {
    await userModel.updateNames(u.user_id, { full_name: fullName, student_id: studentId });
  } catch (e) {
    throw mapDbError(e);
  }
  res.json(publicUser(await userModel.findById(u.user_id)));
}

/** PUT /admin/users/:id/active  { active: true | false }  (suspend / re-open) */
async function setActive(req, res) {
  const u = await getStudent(req);
  const active = bool(req.body?.active);
  if (!active && (await rideModel.findOpenByUser(u.user_id))) throw conflict('This user still has a vehicle out');
  await userModel.setActive(u.user_id, active);
  res.json(publicUser(await userModel.findById(u.user_id)));
}

/** POST /admin/users/:id/credit  { amount (+ add / - take), reason, refund? } -> the updated user */
async function adjustCredit(req, res) {
  const u = await getStudent(req);
  const amount = Number(req.body?.amount);
  const reason = str(req.body?.reason);
  const refund = bool(req.body?.refund);

  if (!Number.isFinite(amount) || amount === 0) throw badRequest('Amount cannot be 0');
  if (!reason) throw badRequest('Please give a reason');
  if (refund && amount < 0) throw badRequest('A refund must be a positive amount');
  if (Number(u.credit_balance) + amount < 0) throw conflict('Credit cannot go below ฿0');

  try {
    await creditModel.callAdjust(u.user_id, Math.round(amount * 100) / 100, refund ? 'refund' : 'adjustment', reason);
  } catch (e) {
    throw mapDbError(e);
  }
  res.json(publicUser(await userModel.findById(u.user_id)));
}

module.exports = { list, detail, update, setActive, adjustCredit };
