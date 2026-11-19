jest.mock('../src/models/userModel');
jest.mock('../src/models/rideModel');
jest.mock('../src/models/creditModel');
const userModel = require('../src/models/userModel');
const rideModel = require('../src/models/rideModel');
const creditModel = require('../src/models/creditModel');
const c = require('../src/controllers/adminUserController');
const { run, fails, student, admin, rideRow } = require('./helpers');

const user = admin();
beforeEach(() => {
  jest.resetAllMocks();
  userModel.findById.mockResolvedValue(student({ credit_balance: 100 }));
  userModel.studentIdTaken.mockResolvedValue(false);
  rideModel.findOpenByUser.mockResolvedValue(null);
});

test('list passes the search text and marks riding as boolean', async () => {
  userModel.listStudents.mockResolvedValue([student({ riding: 1 }), student({ user_id: 3, riding: 0 })]);
  const { body } = await run(c.list, { user, query: { q: ' malee ' } });
  expect(userModel.listStudents).toHaveBeenCalledWith('malee');
  expect(body.map((u) => u.riding)).toEqual([true, false]);
  expect(body[0]).not.toHaveProperty('password_hash');
});

describe('detail', () => {
  test('user + rides + labelled transactions', async () => {
    rideModel.listByUser.mockResolvedValue([rideRow({ is_overdue: 1 })]);
    creditModel.listByUser.mockResolvedValue([{ txn_type: 'topup' }]);
    const { body } = await run(c.detail, { user, params: { id: '1' } });
    expect(body.user.username).toBe('somchai.j');
    expect(body.rides[0].is_overdue).toBe(true);
    expect(body.transactions[0].label).toBe('Top up');
  });
  test('unknown -> 404, admin account -> 403', async () => {
    userModel.findById.mockResolvedValue(null);
    expect(await fails(c.detail, { user, params: { id: '1' } })).toMatchObject({ status: 404, message: 'User not found' });
    expect(await fails(c.detail, { user, params: { id: 'abc' } })).toMatchObject({ status: 404 });
    userModel.findById.mockResolvedValue(admin());
    expect(await fails(c.detail, { user, params: { id: '2' } })).toMatchObject({ status: 403 });
  });
});

describe('update', () => {
  test('ok', async () => {
    await run(c.update, { user, params: { id: '1' }, body: { full_name: ' New Name ', student_id: '6731500000' } });
    expect(userModel.updateNames).toHaveBeenCalledWith(1, { full_name: 'New Name', student_id: '6731500000' });
  });
  test('validation', async () => {
    expect(await fails(c.update, { user, params: { id: '1' }, body: { full_name: '', student_id: '1' } })).toMatchObject({ status: 400 });
    expect(await fails(c.update, { user, params: { id: '1' }, body: { full_name: 'x'.repeat(101), student_id: '1' } })).toMatchObject({ status: 400 });
    userModel.studentIdTaken.mockResolvedValue(true);
    expect(await fails(c.update, { user, params: { id: '1' }, body: { full_name: 'A', student_id: '1' } })).toMatchObject({ status: 409, message: 'This student ID is already used' });
    expect(userModel.updateNames).not.toHaveBeenCalled();
  });
});

describe('setActive', () => {
  test('suspend and re-open', async () => {
    await run(c.setActive, { user, params: { id: '1' }, body: { active: false } });
    expect(userModel.setActive).toHaveBeenLastCalledWith(1, false);
    await run(c.setActive, { user, params: { id: '1' }, body: { active: true } });
    expect(userModel.setActive).toHaveBeenLastCalledWith(1, true);
  });
  test('cannot suspend a user who still has a vehicle out', async () => {
    rideModel.findOpenByUser.mockResolvedValue(rideRow());
    expect(await fails(c.setActive, { user, params: { id: '1' }, body: { active: false } })).toMatchObject({ status: 409, message: 'This user still has a vehicle out' });
    expect(userModel.setActive).not.toHaveBeenCalled();
  });
  test('re-opening is allowed even with an open ride', async () => {
    rideModel.findOpenByUser.mockResolvedValue(rideRow());
    await run(c.setActive, { user, params: { id: '1' }, body: { active: true } });
    expect(userModel.setActive).toHaveBeenCalledWith(1, true);
  });
});

describe('adjustCredit', () => {
  test('add -> adjustment', async () => {
    await run(c.adjustCredit, { user, params: { id: '1' }, body: { amount: 50, reason: ' Goodwill ' } });
    expect(creditModel.callAdjust).toHaveBeenCalledWith(1, 50, 'adjustment', 'Goodwill');
  });
  test('refund flag -> refund', async () => {
    await run(c.adjustCredit, { user, params: { id: '1' }, body: { amount: '30.456', reason: 'Broken bike', refund: true } });
    expect(creditModel.callAdjust).toHaveBeenCalledWith(1, 30.46, 'refund', 'Broken bike');
  });
  test('take credit back', async () => {
    await run(c.adjustCredit, { user, params: { id: '1' }, body: { amount: -100, reason: 'Fix mistake' } });
    expect(creditModel.callAdjust).toHaveBeenCalledWith(1, -100, 'adjustment', 'Fix mistake');
  });
  test.each([[0, 'r', 'Amount cannot be 0'], ['abc', 'r', 'Amount cannot be 0'], [10, '  ', 'Please give a reason']])('%p / %p -> 400', async (amount, reason, msg) => {
    expect(await fails(c.adjustCredit, { user, params: { id: '1' }, body: { amount, reason } })).toMatchObject({ status: 400, message: msg });
  });
  test('negative refund -> 400; would go below 0 -> 409', async () => {
    expect(await fails(c.adjustCredit, { user, params: { id: '1' }, body: { amount: -5, reason: 'r', refund: true } })).toMatchObject({ status: 400, message: 'A refund must be a positive amount' });
    expect(await fails(c.adjustCredit, { user, params: { id: '1' }, body: { amount: -100.01, reason: 'r' } })).toMatchObject({ status: 409, message: 'Credit cannot go below ฿0' });
    expect(creditModel.callAdjust).not.toHaveBeenCalled();
  });
  test('procedure error is mapped', async () => {
    creditModel.callAdjust.mockRejectedValue({ sqlState: '45000', sqlMessage: 'Credit cannot be negative' });
    expect(await fails(c.adjustCredit, { user, params: { id: '1' }, body: { amount: -10, reason: 'r' } })).toMatchObject({ status: 409, message: 'Credit cannot be negative' });
  });
});
