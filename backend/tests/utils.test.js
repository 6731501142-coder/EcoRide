const { AppError, mapDbError, badRequest, unauthorized, forbidden, notFound, conflict } = require('../src/utils/errors');
const { toInt, str, bool, withBools, asyncHandler } = require('../src/utils/helpers');
const password = require('../src/utils/password');
const token = require('../src/utils/token');

describe('errors', () => {
  test('helpers set the HTTP status', () => {
    expect([badRequest('x'), unauthorized('x'), forbidden('x'), notFound('x'), conflict('x')].map((e) => e.status)).toEqual([400, 401, 403, 404, 409]);
    expect(badRequest('boom')).toBeInstanceOf(AppError);
    expect(badRequest('boom').message).toBe('boom');
  });
  test('stored procedure SIGNAL (45000) -> 409 with the procedure message', () => {
    expect(mapDbError({ sqlState: '45000', sqlMessage: 'Not enough credit' })).toMatchObject({ status: 409, message: 'Not enough credit' });
  });
  test('duplicate key errors get a friendly message', () => {
    const dup = (key) => ({ code: 'ER_DUP_ENTRY', errno: 1062, sqlMessage: `Duplicate entry 'x' for key '${key}'` });
    expect(mapDbError(dup('uq_users_username')).message).toBe('Username is already taken');
    expect(mapDbError(dup('uq_users_student_id')).message).toBe('Student ID is already registered');
    expect(mapDbError(dup('uq_vehicles_code')).message).toBe('This vehicle code already exists');
    expect(mapDbError(dup('uq_stations_name')).message).toBe('This name is already used');
    expect(mapDbError(dup('something_else'))).toMatchObject({ status: 409 });
  });
  test('other errors are returned unchanged', () => {
    const e = new Error('disk on fire');
    expect(mapDbError(e)).toBe(e);
    const app = notFound('x');
    expect(mapDbError(app)).toBe(app);
  });
});

describe('helpers', () => {
  test('toInt is strict', () => {
    expect(toInt('12')).toBe(12);
    expect(toInt(' 7 ')).toBe(7);
    expect(toInt(5)).toBe(5);
    expect(toInt('-3')).toBe(-3);
    expect([toInt('12abc'), toInt(1.5), toInt(null), toInt(undefined), toInt(''), toInt({})]).toEqual([null, null, null, null, null, null]);
  });
  test('str trims and never returns null', () => {
    expect(str('  hi ')).toBe('hi');
    expect(str(null)).toBe('');
    expect(str(undefined)).toBe('');
    expect(str(42)).toBe('42');
  });
  test('bool', () => {
    expect([true, 1, '1', 'true'].every(bool)).toBe(true);
    expect([false, 0, '0', 'false', null, undefined, 'yes'].some(bool)).toBe(false);
  });
  test('withBools converts only the listed keys', () => {
    expect(withBools({ a: 1, b: 0, c: 5 }, ['a', 'b'])).toEqual({ a: true, b: false, c: 5 });
    expect(withBools(null, ['a'])).toBeNull();
  });
  test('asyncHandler passes rejected promises to next()', async () => {
    const next = jest.fn();
    const err = new Error('x');
    await asyncHandler(async () => { throw err; })({}, {}, next);
    expect(next).toHaveBeenCalledWith(err);
  });
});

describe('password', () => {
  const BCRYPT = '$2b$10$PiZNx9PQlVBrBbmB0TiYKOlN6aPT9Quuqrn77DMJZyUGNr1LLgPY.'; // from ecoride_db.sql (password123)
  test('hash is argon2id and verifies', async () => {
    const h = await password.hash('password123');
    expect(h).toMatch(/^\$argon2id\$/);
    expect(h.length).toBeLessThanOrEqual(255); // users.password_hash is varchar(255)
    expect(await password.verify('password123', h)).toBe(true);
    expect(await password.verify('password124', h)).toBe(false);
    expect(await password.verify(undefined, h)).toBe(false);
  });
  test('same password gives different hashes (random salt)', async () => {
    expect(await password.hash('password123')).not.toBe(await password.hash('password123'));
  });
  test('still verifies the bcrypt hashes in ecoride_db.sql', async () => {
    expect(await password.verify('password123', BCRYPT)).toBe(true);
    expect(await password.verify('wrong', BCRYPT)).toBe(false);
  });
  test('garbage hash -> false, not an exception', async () => {
    expect(await password.verify('x', 'plaintext')).toBe(false);
    expect(await password.verify('x', '$argon2id$broken')).toBe(false);
    expect(await password.verify('x', null)).toBe(false);
  });
  test('needsRehash: bcrypt yes, fresh argon2id no', async () => {
    expect(password.needsRehash(BCRYPT)).toBe(true);
    expect(password.needsRehash(await password.hash('password123'))).toBe(false);
  });
  test('new password rules (same messages as the app)', () => {
    expect(password.checkNewPassword('short', 'short')).toBe('Password must be at least 8 characters');
    expect(password.checkNewPassword('longenough', 'different1')).toBe('Passwords do not match');
    expect(password.checkNewPassword('longenough', 'longenough')).toBeNull();
    expect(password.checkNewPassword(undefined, undefined)).toBe('Password must be at least 8 characters');
  });
});

describe('token', () => {
  test('sign + verify', () => {
    expect(token.verify(token.sign({ user_id: 5, role: 'admin' }))).toMatchObject({ sub: 5, role: 'admin' });
  });
  test('bad or empty token -> null', () => {
    expect(token.verify('not.a.token')).toBeNull();
    expect(token.verify(undefined)).toBeNull();
  });
});
