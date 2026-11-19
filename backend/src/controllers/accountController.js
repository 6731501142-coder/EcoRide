// "Me": profile, password, avatar   (= updateProfile / changePassword / setAvatar in AppStore)
const userModel = require('../models/userModel');
const password = require('../utils/password');
const uploads = require('../services/uploadService');
const { publicUser } = require('./authController');
const { badRequest, conflict } = require('../utils/errors');
const { str, toInt } = require('../utils/helpers');

const PRESET_AVATARS = 16; // avatars.dart has ids 1..16

/** GET /me */
async function getMe(req, res) {
  res.json(publicUser(await userModel.findById(req.user.user_id)));
}

/** PUT /me  { full_name, student_id, username } */
async function updateProfile(req, res) {
  const me = req.user;
  const fullName = str(req.body?.full_name);
  const studentId = str(req.body?.student_id);
  const username = str(req.body?.username);
  if (!fullName || !studentId || !username) throw badRequest('Please fill in every field');
  if (fullName.length > 100 || studentId.length > 20 || username.length > 50) throw badRequest('Text is too long');
  if (await userModel.usernameTaken(username, me.user_id)) throw conflict('Username is already taken');
  if (await userModel.studentIdTaken(studentId, me.user_id)) throw conflict('Student ID is already registered');

  await userModel.updateProfile(me.user_id, { full_name: fullName, student_id: studentId, username });
  res.json(publicUser(await userModel.findById(me.user_id)));
}

/** PUT /me/password  { current, password, confirm } */
async function changePassword(req, res) {
  const b = req.body || {};
  const hash = await userModel.getPasswordHash(req.user.user_id);
  if (!(await password.verify(b.current, hash))) throw badRequest('Current password is incorrect');
  const err = password.checkNewPassword(b.password, b.confirm);
  if (err) throw badRequest(err);
  await userModel.updatePassword(req.user.user_id, await password.hash(b.password));
  res.json({ ok: true });
}

/** PUT /me/avatar  { avatar_id: 1..16 }  (a preset avatar; removes an uploaded photo) */
async function setPresetAvatar(req, res) {
  const id = toInt(req.body?.avatar_id);
  if (id === null || id < 1 || id > PRESET_AVATARS) throw badRequest(`avatar_id must be 1-${PRESET_AVATARS}`);
  uploads.removeImage(req.user.avatar_url);
  await userModel.setAvatar(req.user.user_id, { avatar_id: id, avatar_url: null });
  res.json(publicUser(await userModel.findById(req.user.user_id)));
}

/** POST /me/avatar/photo  { image_base64, mime }  (an uploaded photo; removes the preset) */
async function uploadAvatar(req, res) {
  const url = uploads.saveImage({ imageBase64: req.body?.image_base64, mime: req.body?.mime, prefix: `avatar-${req.user.user_id}` });
  uploads.removeImage(req.user.avatar_url);
  await userModel.setAvatar(req.user.user_id, { avatar_id: null, avatar_url: url });
  res.json(publicUser(await userModel.findById(req.user.user_id)));
}

/** DELETE /me/avatar  (setAvatar(null) in the app) */
async function removeAvatar(req, res) {
  uploads.removeImage(req.user.avatar_url);
  await userModel.setAvatar(req.user.user_id, {});
  res.json(publicUser(await userModel.findById(req.user.user_id)));
}

module.exports = { getMe, updateProfile, changePassword, setPresetAvatar, uploadAvatar, removeAvatar, PRESET_AVATARS };
