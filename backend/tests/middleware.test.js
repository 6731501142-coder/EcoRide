jest.mock('../src/models/userModel');
const userModel = require('../src/models/userModel');
const token = require('../src/utils/token');
const { authenticate, requireAdmin } = require('../src/middleware/auth');
const { errorHandler, notFoundHandler } = require('../src/middleware/errorHandler');
const { notFound } = require('../src/utils/errors');
const { student, admin } = require('./helpers');

const call = async (mw, req) => {
  const next = jest.fn();
  await mw(req, {}, next);
  return { next, err: next.mock.calls[0]?.[0], req };
};
const bearer = (u) => ({ headers: { authorization: `Bearer ${token.sign(u)}` } });

beforeEach(() => jest.resetAllMocks());

describe('authenticate', () => {
  test('valid token -> req.user is the user from the DB', async () => {
    userModel.findById.mockResolvedValue(student());
    const { err, req } = await call(authenticate, bearer(student()));
    expect(err).toBeUndefined();
    expect(req.user.username).toBe('somchai.j');
    expect(userModel.findById).toHaveBeenCalledWith(1);
  });
  test('no header / wrong scheme / bad token -> 401', async () => {
    for (const headers of [{}, { authorization: 'Basic abc' }, { authorization: 'Bearer nonsense' }]) {
      expect((await call(authenticate, { headers })).err).toMatchObject({ status: 401, message: 'Please log in' });
    }
    expect(userModel.findById).not.toHaveBeenCalled();
  });
  test('token for a user that no longer exists -> 401', async () => {
    userModel.findById.mockResolvedValue(null);
    expect((await call(authenticate, bearer(student()))).err).toMatchObject({ status: 401 });
  });
  test('account disabled by the admin -> locked out at once (403)', async () => {
    userModel.findById.mockResolvedValue(student({ is_active: 0 }));
    expect((await call(authenticate, bearer(student()))).err).toMatchObject({ status: 403, message: 'This account has been disabled' });
  });
  test('a DB failure goes to the error handler', async () => {
    userModel.findById.mockRejectedValue(new Error('db down'));
    expect((await call(authenticate, bearer(student()))).err.message).toBe('db down');
  });
});

describe('requireAdmin', () => {
  test('admin passes', async () => {
    expect((await call(requireAdmin, { user: admin() })).err).toBeUndefined();
  });
  test('student or missing user -> 403', async () => {
    expect((await call(requireAdmin, { user: student() })).err).toMatchObject({ status: 403, message: 'Admins only' });
    expect((await call(requireAdmin, {})).err).toMatchObject({ status: 403 });
  });
});

describe('errorHandler', () => {
  const res = () => {
    const r = { status: jest.fn(() => r), json: jest.fn(() => r) };
    return r;
  };
  test('AppError -> its status and { error }', () => {
    const r = res();
    errorHandler(notFound('Ride not found'), {}, r, () => {});
    expect(r.status).toHaveBeenCalledWith(404);
    expect(r.json).toHaveBeenCalledWith({ error: 'Ride not found' });
  });
  test('stored procedure error -> 409 with its message', () => {
    const r = res();
    errorHandler({ sqlState: '45000', sqlMessage: 'Station is full' }, {}, r, () => {});
    expect(r.status).toHaveBeenCalledWith(409);
    expect(r.json).toHaveBeenCalledWith({ error: 'Station is full' });
  });
  test('broken JSON -> 400, huge body -> 413', () => {
    let r = res();
    errorHandler({ type: 'entity.parse.failed' }, {}, r, () => {});
    expect(r.status).toHaveBeenCalledWith(400);
    r = res();
    errorHandler({ type: 'entity.too.large' }, {}, r, () => {});
    expect(r.status).toHaveBeenCalledWith(413);
  });
  test('unknown error -> 500 and the details are NOT sent to the client', () => {
    const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
    const r = res();
    errorHandler(new Error('secret SQL details'), {}, r, () => {});
    expect(r.status).toHaveBeenCalledWith(500);
    expect(r.json).toHaveBeenCalledWith({ error: 'Internal server error' });
    spy.mockRestore();
  });
  test('unknown route -> 404', () => {
    const r = res();
    notFoundHandler({}, r);
    expect(r.status).toHaveBeenCalledWith(404);
  });
});
