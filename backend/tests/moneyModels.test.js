const { db, sql, params } = require('./modelHelpers');
const topups = require('../src/models/topupModel');
const credit = require('../src/models/creditModel');

beforeEach(() => jest.resetAllMocks());

describe('topupModel', () => {
  test('finders', async () => {
    db.query.mockResolvedValue([{ topup_id: 3 }]);
    expect(await topups.findById(3)).toEqual({ topup_id: 3 });
    expect(sql()).toContain('JOIN users');
    await topups.listAll();
    expect(sql()).toContain('ORDER BY t.created_at DESC');
    await topups.listPending();
    expect(sql()).toContain("t.status = 'pending'");
    expect(sql()).toContain('ORDER BY t.created_at ASC'); // oldest waiting first
    db.query.mockResolvedValue([]);
    expect(await topups.findById(9)).toBeNull();
  });
  test('create: a new top-up is always a pending QR payment', async () => {
    db.query.mockResolvedValue({ insertId: 8 });
    expect(await topups.create({ user_id: 1, amount: 200, reference_code: 'ECO1-ABC' })).toBe(8);
    expect(sql()).toContain("'qr'");
    expect(sql()).toContain("'pending'");
    expect(params()).toEqual([1, 200, 'ECO1-ABC']);
  });
  test('callConfirm = sp_confirm_topup', async () => {
    await topups.callConfirm(8);
    expect(sql()).toBe('CALL sp_confirm_topup(?)');
    expect(params()).toEqual([8]);
  });
  test('markFailed only touches pending top-ups and returns the changed row count', async () => {
    db.query.mockResolvedValue({ affectedRows: 1 });
    expect(await topups.markFailed(8)).toBe(1);
    expect(sql()).toContain("AND status = 'pending'");
    db.query.mockResolvedValue({ affectedRows: 0 });
    expect(await topups.markFailed(8)).toBe(0);
  });
  test('paidThisMonth returns a number (0 when nothing paid)', async () => {
    db.query.mockResolvedValue([{ total: '350.00' }]);
    expect(await topups.paidThisMonth()).toBe(350);
    expect(sql()).toContain("status = 'paid'");
    db.query.mockResolvedValue([{ total: 0 }]);
    expect(await topups.paidThisMonth()).toBe(0);
  });
});

describe('creditModel', () => {
  test('listByUser / listAll join the vehicle code, newest first', async () => {
    db.query.mockResolvedValue([{ txn_id: 1 }]);
    expect(await credit.listByUser(1)).toEqual([{ txn_id: 1 }]);
    expect(sql()).toContain('v.vehicle_code');
    expect(sql()).toContain('WHERE t.user_id = ?');
    expect(params()).toEqual([1]);
    await credit.listAll();
    expect(sql()).not.toContain('WHERE');
    expect(sql()).toContain('ORDER BY t.created_at DESC, t.txn_id DESC');
  });
  test('revenueThisMonth: ride payments only, returned as a positive number', async () => {
    db.query.mockResolvedValue([{ total: '300.00' }]);
    expect(await credit.revenueThisMonth()).toBe(300);
    expect(sql()).toContain("txn_type = 'ride_payment'");
    expect(sql()).toContain('-SUM(amount)');
  });
  test('callAdjust = sp_adjust_credit(user, amount, type, note)', async () => {
    await credit.callAdjust(3, -20, 'adjustment', 'mistake');
    expect(sql()).toBe('CALL sp_adjust_credit(?, ?, ?, ?)');
    expect(params()).toEqual([3, -20, 'adjustment', 'mistake']);
  });
});
