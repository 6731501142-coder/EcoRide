jest.mock('../src/models/topupModel');
jest.mock('../src/models/creditModel');
jest.mock('../src/models/userModel');
const topupModel = require('../src/models/topupModel');
const creditModel = require('../src/models/creditModel');
const userModel = require('../src/models/userModel');
const config = require('../src/config');
const c = require('../src/controllers/creditController');
const { run, fails, student, admin } = require('./helpers');

const user = student();
beforeEach(() => {
  jest.resetAllMocks();
  config.allowSelfConfirmTopup = true;
  topupModel.create.mockResolvedValue(3);
  topupModel.findById.mockResolvedValue({ topup_id: 3, user_id: 1, amount: 100, status: 'pending' });
  userModel.findById.mockResolvedValue(student({ credit_balance: 250 }));
});

describe('txnLabel', () => {
  test('mirrors AppStore.txnLabel', () => {
    expect(c.txnLabel({ ride_id: 7, vehicle_code: 'EB-012', txn_type: 'ride_payment' })).toBe('Ride · EB-012');
    expect(c.txnLabel({ note: 'Late fee waived', txn_type: 'adjustment' })).toBe('Late fee waived');
    expect(c.txnLabel({ txn_type: 'topup' })).toBe('Top up');
    expect(c.txnLabel({ txn_type: 'ride_payment' })).toBe('Ride payment');
    expect(c.txnLabel({ txn_type: 'refund' })).toBe('Refund');
    expect(c.txnLabel({ txn_type: 'adjustment' })).toBe('Adjustment');
  });
});

test('myTransactions adds a label to each row', async () => {
  creditModel.listByUser.mockResolvedValue([{ txn_type: 'topup', amount: 100 }]);
  const { body } = await run(c.myTransactions, { user });
  expect(creditModel.listByUser).toHaveBeenCalledWith(1);
  expect(body[0]).toMatchObject({ txn_type: 'topup', label: 'Top up' });
});

describe('createTopup', () => {
  test('ok -> 201 with a unique-looking reference', async () => {
    const { status } = await run(c.createTopup, { user, body: { amount: 100 } });
    expect(status).toBe(201);
    const arg = topupModel.create.mock.calls[0][0];
    expect(arg).toMatchObject({ user_id: 1, amount: 100 });
    expect(arg.reference_code).toMatch(/^ECO1-[0-9A-Z]+$/);
  });
  test('boundaries 20 and 5000 are allowed, strings are parsed', async () => {
    await run(c.createTopup, { user, body: { amount: 20 } });
    await run(c.createTopup, { user, body: { amount: '5000' } });
    expect(topupModel.create).toHaveBeenCalledTimes(2);
  });
  test('two topups never share a reference', async () => {
    await run(c.createTopup, { user, body: { amount: 50 } });
    await run(c.createTopup, { user, body: { amount: 50 } });
    const [a, b] = topupModel.create.mock.calls.map((x) => x[0].reference_code);
    expect(a).not.toBe(b);
  });
  test.each([19.99, 5001, 0, -5, 'abc', '', null, undefined, NaN])('amount %p -> 400', async (amount) => {
    expect(await fails(c.createTopup, { user, body: { amount } })).toMatchObject({ status: 400, message: 'Top-up must be between ฿20 and ฿5,000' });
    expect(topupModel.create).not.toHaveBeenCalled();
  });
});

describe('confirmTopup', () => {
  test('owner confirms own top-up (self-confirm on) -> procedure called, new balance returned', async () => {
    const { body } = await run(c.confirmTopup, { user, params: { id: '3' } });
    expect(topupModel.callConfirm).toHaveBeenCalledWith(3);
    expect(body.user.credit_balance).toBe(250);
  });
  test('self-confirm off -> students get 403, admins still can', async () => {
    config.allowSelfConfirmTopup = false;
    expect(await fails(c.confirmTopup, { user, params: { id: '3' } })).toMatchObject({ status: 403 });
    expect(topupModel.callConfirm).not.toHaveBeenCalled();
    await run(c.confirmTopup, { user: admin(), params: { id: '3' } });
    expect(topupModel.callConfirm).toHaveBeenCalledWith(3);
  });
  test("someone else's top-up -> 403", async () => {
    expect(await fails(c.confirmTopup, { user: student({ user_id: 99 }), params: { id: '3' } })).toMatchObject({ status: 403 });
  });
  test('unknown id -> 404, already paid -> 409', async () => {
    topupModel.findById.mockResolvedValue(null);
    expect(await fails(c.confirmTopup, { user, params: { id: '3' } })).toMatchObject({ status: 404 });
    expect(await fails(c.confirmTopup, { user, params: { id: 'x' } })).toMatchObject({ status: 404 });
    topupModel.findById.mockResolvedValue({ topup_id: 3, user_id: 1, status: 'paid' });
    expect(await fails(c.confirmTopup, { user, params: { id: '3' } })).toMatchObject({ status: 409 });
  });
  test('procedure error is mapped', async () => {
    topupModel.callConfirm.mockRejectedValue({ sqlState: '45000', sqlMessage: 'Top-up is not pending' });
    expect(await fails(c.confirmTopup, { user, params: { id: '3' } })).toMatchObject({ status: 409, message: 'Top-up is not pending' });
  });
});
