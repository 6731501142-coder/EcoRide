jest.mock('../src/models/userModel');
jest.mock('../src/services/uploadService');
const userModel = require('../src/models/userModel');
const uploads = require('../src/services/uploadService');
const password = require('../src/utils/password');
const c = require('../src/controllers/accountController');
const { run, fails, student } = require('./helpers');

const user = student({ avatar_url: '/uploads/old.png' });
beforeEach(() => {
  jest.resetAllMocks();
  userModel.findById.mockResolvedValue(student());
  userModel.usernameTaken.mockResolvedValue(false);
  userModel.studentIdTaken.mockResolvedValue(false);
});

test('getMe returns the fresh user', async () => {
  const { body } = await run(c.getMe, { user });
  expect(userModel.findById).toHaveBeenCalledWith(1);
  expect(body.username).toBe('somchai.j');
});

describe('updateProfile', () => {
  const good = { full_name: ' Somchai J. ', student_id: '6731501118', username: 'somchai2' };
  test('ok (values trimmed, uniqueness checked excluding myself)', async () => {
    await run(c.updateProfile, { user, body: good });
    expect(userModel.updateProfile).toHaveBeenCalledWith(1, { full_name: 'Somchai J.', student_id: '6731501118', username: 'somchai2' });
    expect(userModel.usernameTaken).toHaveBeenCalledWith('somchai2', 1);
    expect(userModel.studentIdTaken).toHaveBeenCalledWith('6731501118', 1);
  });
  test('empty field -> 400; too long -> 400', async () => {
    expect(await fails(c.updateProfile, { user, body: { ...good, username: '' } })).toMatchObject({ status: 400, message: 'Please fill in every field' });
    expect(await fails(c.updateProfile, { user, body: { ...good, full_name: 'x'.repeat(101) } })).toMatchObject({ status: 400, message: 'Text is too long' });
  });
  test('taken -> 409', async () => {
    userModel.usernameTaken.mockResolvedValue(true);
    expect(await fails(c.updateProfile, { user, body: good })).toMatchObject({ status: 409, message: 'Username is already taken' });
    userModel.usernameTaken.mockResolvedValue(false);
    userModel.studentIdTaken.mockResolvedValue(true);
    expect(await fails(c.updateProfile, { user, body: good })).toMatchObject({ status: 409, message: 'Student ID is already registered' });
    expect(userModel.updateProfile).not.toHaveBeenCalled();
  });
});

describe('changePassword', () => {
  let hash;
  beforeAll(async () => { hash = await password.hash('password123'); });
  beforeEach(() => userModel.getPasswordHash.mockResolvedValue(hash));
  test('ok', async () => {
    const { body } = await run(c.changePassword, { user, body: { current: 'password123', password: 'newpassword1', confirm: 'newpassword1' } });
    expect(body).toEqual({ ok: true });
    expect(userModel.updatePassword).toHaveBeenCalledWith(1, expect.stringMatching(/^\$argon2id\$/));
  });
  test('wrong current password -> 400', async () => {
    expect(await fails(c.changePassword, { user, body: { current: 'bad', password: 'newpassword1', confirm: 'newpassword1' } })).toMatchObject({ status: 400, message: 'Current password is incorrect' });
  });
  test('weak / mismatch -> 400', async () => {
    expect(await fails(c.changePassword, { user, body: { current: 'password123', password: 'abc', confirm: 'abc' } })).toMatchObject({ status: 400, message: 'Password must be at least 8 characters' });
    expect(await fails(c.changePassword, { user, body: { current: 'password123', password: 'newpassword1', confirm: 'other' } })).toMatchObject({ status: 400, message: 'Passwords do not match' });
    expect(userModel.updatePassword).not.toHaveBeenCalled();
  });
});

describe('avatars', () => {
  test('preset 1..16 ok, removes an uploaded photo', async () => {
    await run(c.setPresetAvatar, { user, body: { avatar_id: 16 } });
    expect(userModel.setAvatar).toHaveBeenCalledWith(1, { avatar_id: 16, avatar_url: null });
    expect(uploads.removeImage).toHaveBeenCalledWith('/uploads/old.png');
  });
  test.each([0, 17, 'abc', null, 1.5])('preset %p -> 400', async (v) => {
    expect(await fails(c.setPresetAvatar, { user, body: { avatar_id: v } })).toMatchObject({ status: 400, message: 'avatar_id must be 1-16' });
    expect(userModel.setAvatar).not.toHaveBeenCalled();
  });
  test('upload photo: saved, old one removed, preset cleared', async () => {
    uploads.saveImage.mockReturnValue('/uploads/avatar-1-new.png');
    await run(c.uploadAvatar, { user, body: { image_base64: 'AAA', mime: 'image/png' } });
    expect(uploads.saveImage).toHaveBeenCalledWith({ imageBase64: 'AAA', mime: 'image/png', prefix: 'avatar-1' });
    expect(userModel.setAvatar).toHaveBeenCalledWith(1, { avatar_id: null, avatar_url: '/uploads/avatar-1-new.png' });
    expect(uploads.removeImage).toHaveBeenCalledWith('/uploads/old.png');
  });
  test('upload errors from the service propagate and nothing changes', async () => {
    uploads.saveImage.mockImplementation(() => { throw Object.assign(new Error('Image is empty'), { status: 400 }); });
    expect(await fails(c.uploadAvatar, { user, body: {} })).toMatchObject({ status: 400 });
    expect(userModel.setAvatar).not.toHaveBeenCalled();
  });
  test('remove avatar = back to initials', async () => {
    await run(c.removeAvatar, { user });
    expect(userModel.setAvatar).toHaveBeenCalledWith(1, {});
    expect(uploads.removeImage).toHaveBeenCalledWith('/uploads/old.png');
  });
});
