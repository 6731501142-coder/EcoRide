// credit_transactions + the admin credit adjustment
const db = require('../db');

const SELECT = `SELECT t.txn_id, t.user_id, t.txn_type, t.amount, t.balance_after, t.ride_id, t.topup_id,
  t.note, t.created_at, v.vehicle_code
  FROM credit_transactions t
  LEFT JOIN rides r ON r.ride_id = t.ride_id
  LEFT JOIN vehicles v ON v.vehicle_id = r.vehicle_id`;

const listByUser = (userId) => db.query(`${SELECT} WHERE t.user_id = ? ORDER BY t.created_at DESC, t.txn_id DESC`, [userId]);

const listAll = () => db.query(`${SELECT} ORDER BY t.created_at DESC, t.txn_id DESC`);

/** revenue = money taken for rides this month (credit left in wallets is NOT revenue) */
const revenueThisMonth = async () =>
  Number(
    (await db.query(
      `SELECT COALESCE(-SUM(amount), 0) AS total FROM credit_transactions
       WHERE txn_type = 'ride_payment' AND created_at >= DATE_FORMAT(CURDATE(), '%Y-%m-01')`
    ))[0].total
  );

/** sp_adjust_credit(user, amount, 'refund' | 'adjustment', note) */
const callAdjust = (userId, amount, type, note) =>
  db.query('CALL sp_adjust_credit(?, ?, ?, ?)', [userId, amount, type, note]);

module.exports = { listByUser, listAll, revenueThisMonth, callAdjust };
