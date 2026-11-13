const db = require('../db');

const SELECT = `SELECT t.topup_id, t.user_id, t.amount, t.payment_method, t.reference_code, t.status,
  t.created_at, t.paid_at, u.full_name, u.username
  FROM topups t JOIN users u ON u.user_id = t.user_id`;

const findById = async (id) => (await db.query(`${SELECT} WHERE t.topup_id = ?`, [id]))[0] || null;
const listAll = () => db.query(`${SELECT} ORDER BY t.created_at DESC, t.topup_id DESC`);
const listPending = () => db.query(`${SELECT} WHERE t.status = 'pending' ORDER BY t.created_at ASC`);

async function create({ user_id, amount, reference_code }) {
  const r = await db.query(
    `INSERT INTO topups (user_id, amount, payment_method, reference_code, status) VALUES (?, ?, 'qr', ?, 'pending')`,
    [user_id, amount, reference_code]
  );
  return r.insertId;
}

/** sp_confirm_topup(topup): marks paid + adds credit + writes the credit_transactions row */
const callConfirm = (topupId) => db.query('CALL sp_confirm_topup(?)', [topupId]);

/** money did not arrive -> failed. Returns how many rows changed (0 = was not pending). */
async function markFailed(topupId) {
  const r = await db.query(`UPDATE topups SET status = 'failed' WHERE topup_id = ? AND status = 'pending'`, [topupId]);
  return r.affectedRows;
}

/** total of top-ups paid this month (admin Overview) */
const paidThisMonth = async () =>
  Number(
    (await db.query(
      `SELECT COALESCE(SUM(amount), 0) AS total FROM topups
       WHERE status = 'paid' AND paid_at >= DATE_FORMAT(CURDATE(), '%Y-%m-01')`
    ))[0].total
  );

module.exports = { findById, listAll, listPending, create, callConfirm, markFailed, paidThisMonth };
