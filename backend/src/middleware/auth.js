const token = require('../utils/token');
const userModel = require('../models/userModel');
const { unauthorized, forbidden } = require('../utils/errors');

/**
 * Reads "Authorization: Bearer <token>", loads the user from the DB every time
 * (so an admin disabling an account locks that student out immediately) and sets req.user.
 */
async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const payload = header.startsWith('Bearer ') ? token.verify(header.slice(7)) : null;
    if (!payload) throw unauthorized('Please log in');

    const user = await userModel.findById(payload.sub);
    if (!user) throw unauthorized('Please log in');
    if (!user.is_active) throw forbidden('This account has been disabled');

    req.user = user;
    next();
  } catch (e) {
    next(e);
  }
}

/** use after authenticate */
function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') return next(forbidden('Admins only'));
  next();
}

module.exports = { authenticate, requireAdmin };
