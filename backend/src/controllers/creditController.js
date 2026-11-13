// Top-up (QR) and payment history   (= createTopup / confirmTopup / myTransactions in AppStore)
const crypto = require('crypto');
const topupModel = require('../models/topupModel');
const creditModel = require('../models/creditModel');
const userModel = require('../models/userModel');
const config = require('../config');
const { badRequest, notFound, forbidden, conflict, mapDbError } = require('../utils/errors');
const { toInt } = require('../utils/helpers');
const { publicUser } = require('./authController');

const baht = (n) => `฿${Number(n).toLocaleString('en-US')}`;

/** the label the app shows in Payment history (= AppStore.txnLabel) */
function txnLabel(t) {
  if (t.ride_id != null && t.vehicle_code) return `Ride · ${t.vehicle_code}`;
  if (t.note) return t.note;
  return { topup: 'Top up', ride_payment: 'Ride payment', refund: 'Refund' }[t.txn_type] || 'Adjustment';
}

const withLabel = (t) => ({ ...t, label: txnLabel(t) });

/** GET /credit/transactions  -> my payment history, newest first */
async function myTransactions(req, res) {
  res.json((await creditModel.listByUser(req.user.user_id)).map(withLabel));
}

/** POST /topups  { amount } -> 201 pending top-up (the app then shows the QR) */
async function createTopup(req, res) {
  const raw = req.body?.amount;
  const amount = typeof raw === 'number' ? raw : Number(String(raw ?? '').trim());
  if (!Number.isFinite(amount) || amount < config.minTopup || amount > config.maxTopup) {
    throw badRequest(`Top-up must be between ${baht(config.minTopup)} and ${baht(config.maxTopup)}`);
  }
  const rounded = Math.round(amount * 100) / 100;
  const reference = `ECO${req.user.user_id}-${Date.now().toString(36)}${crypto.randomBytes(3).toString('hex')}`.toUpperCase();
  const id = await topupModel.create({ user_id: req.user.user_id, amount: rounded, reference_code: reference });
  res.status(201).json(await topupModel.findById(id));
}

/**
 * POST /topups/:id/confirm   (also used by POST /admin/topups/:id/confirm)
 * The app confirms right after the QR payment. There is no real payment gateway yet, so by default
 * a student may confirm their own pending top-up (ALLOW_SELF_CONFIRM_TOPUP=false -> admin only).
 */
async function confirmTopup(req, res) {
  const id = toInt(req.params.id);
  const t = id === null ? null : await topupModel.findById(id);
  if (!t) throw notFound('Top-up not found or not pending');

  const isAdmin = req.user.role === 'admin';
  const isOwner = t.user_id === req.user.user_id;
  if (!isAdmin && !(isOwner && config.allowSelfConfirmTopup)) throw forbidden('Only an admin can confirm this top-up');
  if (t.status !== 'pending') throw conflict('Top-up not found or not pending');

  try {
    await topupModel.callConfirm(t.topup_id);
  } catch (e) {
    throw mapDbError(e);
  }
  res.json({
    topup: await topupModel.findById(t.topup_id),
    user: publicUser(await userModel.findById(t.user_id)),
  });
}

module.exports = { myTransactions, createTopup, confirmTopup, txnLabel, withLabel };
