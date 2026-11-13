jest.mock('../src/models/userModel');
const userModel = require('../src/models/userModel');
const password = require('../src/utils/password');
const token = require('../src/utils/token');
const c = require('../src/controllers/authController');
const { run, fails, student } = require('./helpers');

let hash;
beforeAll(async () => { hash = await password.hash('password123'); });
beforeEach(() => jest.resetAllMocks());

describe('login', () => {
  test('ok -> token + user without password_hash, is_active boolean', async () => {
    userModel.findByUsernameWithHash.mockResolvedValue({ ...student(), password_hash: hash });
    const { body } = await run(c.login, { body: { username: ' somchai.j ', password: 'password123' } });
    expect(userModel.findByUsernameWithHash).toHaveBeenCalledWith('somchai.j');
    expect(token.verify(body.token)).toMatchObject({ sub: 1, role: 'student' });
    expect(body.user).not.toHaveProperty('password_hash');
    expect(body.user.is_active).toBe(true);
  });
  test('old bcrypt hash: login works and the hash is upgraded to argon2id', async () => {
    const bcrypt = require('bcryptjs');
    userModel.findByUsernameWithHash.mockResolvedValue({ ...student(), password_hash: await bcrypt.hash('password123', 4) });
    await run(c.login, { body: { username: 'somchai.j', password: 'password123' } });
    expect(userModel.updatePassword).toHaveBeenCalledWith(1, expect.stringMatching(/^\$argon2id\$/));
  });
  test('argon2 hash: no rehash on login; a failing rehash does not block login', async () => {
    userModel.findByUsernameWithHash.mockResolvedValue({ ...student(), password_hash: hash });
    await run(c.login, { body: { username: 'somchai.j', password: 'password123' } });
    expect(userModel.updatePassword).not.toHaveBeenCalled();
    userModel.findByUsernameWithHash.mockResolvedValue({ ...student(), password_hash: await require('bcryptjs').hash('password123', 4) });
    userModel.updatePassword.mockRejectedValue(new Error('db'));
    const { body } = await run(c.login, { body: { username: 'somchai.j', password: 'password123' } });
    expect(body.token).toBeTruthy();
  });
  test('wrong password / unknown user / empty -> same 401 message', async () => {
    userModel.findByUsernameWithHash.mockResolvedValue({ ...student(), password_hash: hash });
    expect(await fails(c.login, { body: { username: 'somchai.j', password: 'nope' } })).toMatchObject({ status: 401, message: 'Wrong username or password' });
    userModel.findByUsernameWithHash.mockResolvedValue(null);
    expect(await fails(c.login, { body: { username: 'ghost', password: 'password123' } })).toMatchObject({ status: 401, message: 'Wrong username or password' });
    expect(await fails(c.login, { body: {} })).toMatchObject({ status: 401 });
  });
  test('disabled account -> 403', async () => {
    userModel.findByUsernameWithHash.mockResolvedValue({ ...student({ is_active: 0 }), password_hash: hash });
    expect(await fails(c.login, { body: { username: 'somchai.j', password: 'password123' } })).toMatchObject({ status: 403 });
  });
});

describe('register', () => {
  const good = { full_name: ' New Student ', student_id: '6731501999', username: 'new.s', password: 'password123', confirm: 'password123' };
  beforeEach(() => {
    userModel.usernameTaken.mockResolvedValue(false);
    userModel.studentIdTaken.mockResolvedValue(false);
    userModel.create.mockResolvedValue(9);
    userModel.findById.mockResolvedValue(student({ user_id: 9, username: 'new.s' }));
  });
  test('ok -> 201, password stored as bcrypt hash', async () => {
    const { status, body } = await run(c.register, { body: good });
    expect(status).toBe(201);
    const arg = userModel.create.mock.calls[0][0];
    expect(arg).toMatchObject({ student_id: '6731501999', username: 'new.s', full_name: 'New Student' });
    expect(arg.password_hash).toMatch(/^\$argon2id\$/);
    expect(arg.password_hash).not.toBe('password123');
    expect(body.user).not.toHaveProperty('password_hash');
  });
  test.each([
    [{ full_name: '' }, 'Please fill in every field'],
    [{ username: '   ' }, 'Please fill in every field'],
    [{ password: '' }, 'Please fill in every field'],
    [{ full_name: 'x'.repeat(101) }, 'Full name is too long (max 100 characters)'],
    [{ student_id: 'x'.repeat(21) }, 'Student ID is too long (max 20 characters)'],
    [{ username: 'x'.repeat(51) }, 'Username is too long (max 50 characters)'],
    [{ password: 'short', confirm: 'short' }, 'Password must be at least 8 characters'],
    [{ confirm: 'different123' }, 'Passwords do not match'],
  ])('bad input %j -> 400 %s', async (patch, msg) => {
    expect(await fails(c.register, { body: { ...good, ...patch } })).toMatchObject({ status: 400, message: msg });
    expect(userModel.create).not.toHaveBeenCalled();
  });
  test('taken username / student id -> 409', async () => {
    userModel.usernameTaken.mockResolvedValue(true);
    expect(await fails(c.register, { body: good })).toMatchObject({ status: 409, message: 'Username is already taken' });
    userModel.usernameTaken.mockResolvedValue(false);
    userModel.studentIdTaken.mockResolvedValue(true);
    expect(await fails(c.register, { body: good })).toMatchObject({ status: 409, message: 'Student ID is already registered' });
  });
  test('race: DB duplicate error is mapped to 409', async () => {
    userModel.create.mockRejectedValue({ code: 'ER_DUP_ENTRY', errno: 1062, sqlMessage: "Duplicate entry 'x' for key 'uq_users_username'" });
    expect(await fails(c.register, { body: good })).toMatchObject({ status: 409, message: 'Username is already taken' });
  });
});

describe('findUsername', () => {
  test('ok (name is case-insensitive)', async () => {
    userModel.findByStudentId.mockResolvedValue(student());
    const { body } = await run(c.findUsername, { body: { student_id: '6731501118', full_name: 'somchai JAIDEE' } });
    expect(body).toEqual({ username: 'somchai.j' });
  });
  test('missing fields -> 400, no match -> 404', async () => {
    expect(await fails(c.findUsername, { body: { student_id: '1' } })).toMatchObject({ status: 400 });
    userModel.findByStudentId.mockResolvedValue(student());
    expect(await fails(c.findUsername, { body: { student_id: '6731501118', full_name: 'Someone Else' } })).toMatchObject({ status: 404, message: 'No account matches this student ID and name' });
    userModel.findByStudentId.mockResolvedValue(null);
    expect(await fails(c.findUsername, { body: { student_id: '0', full_name: 'x' } })).toMatchObject({ status: 404 });
  });
});

describe('resetPassword', () => {
  const good = { username: 'somchai.j', student_id: '6731501118', full_name: 'Somchai Jaidee', password: 'newpassword1', confirm: 'newpassword1' };
  beforeEach(() => userModel.findByUsername.mockResolvedValue(student()));
  test('ok -> new hash saved', async () => {
    const { body } = await run(c.resetPassword, { body: good });
    expect(body).toEqual({ ok: true });
    expect(userModel.updatePassword).toHaveBeenCalledWith(1, expect.stringMatching(/^\$argon2id\$/));
  });
  test('missing field -> 400', async () => {
    expect(await fails(c.resetPassword, { body: { ...good, username: '' } })).toMatchObject({ status: 400, message: 'Please fill in every field' });
  });
  test('identity mismatch -> 400 with the app message', async () => {
    for (const patch of [{ student_id: '000' }, { full_name: 'Other Name' }]) {
      expect(await fails(c.resetPassword, { body: { ...good, ...patch } })).toMatchObject({ status: 400, message: 'Username, student ID and full name do not match' });
    }
    userModel.findByUsername.mockResolvedValue(null);
    expect(await fails(c.resetPassword, { body: good })).toMatchObject({ status: 400 });
    expect(userModel.updatePassword).not.toHaveBeenCalled();
  });
  test('weak / mismatching password -> 400', async () => {
    expect(await fails(c.resetPassword, { body: { ...good, password: 'abc', confirm: 'abc' } })).toMatchObject({ status: 400, message: 'Password must be at least 8 characters' });
    expect(await fails(c.resetPassword, { body: { ...good, confirm: 'zzzzzzzzzz' } })).toMatchObject({ status: 400, message: 'Passwords do not match' });
  });
});

describe('publicUser', () => {
  test('strips the hash, handles null', () => {
    expect(c.publicUser({ ...student(), password_hash: 'x' })).not.toHaveProperty('password_hash');
    expect(c.publicUser(null)).toBeNull();
  });
});
