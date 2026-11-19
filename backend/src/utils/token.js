const jwt = require('jsonwebtoken');
const config = require('../config');

const sign = (user) =>
  jwt.sign({ sub: user.user_id, role: user.role }, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
  });

/** returns the payload, or null if the token is missing / wrong / expired */
function verify(token) {
  try {
    return jwt.verify(token, config.jwtSecret);
  } catch {
    return null;
  }
}

module.exports = { sign, verify };
