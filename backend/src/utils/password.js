const argon2 = require('argon2');
const bcrypt = require('bcryptjs');

// New passwords use argon2id (OWASP defaults: 64 MiB, 3 passes). The demo users in ecoride_db.sql still have
// bcrypt hashes ($2b$...), so verify() accepts both and login upgrades old hashes (see needsRehash).
const OPTIONS = { type: argon2.argon2id, memoryCost: 65536, timeCost: 3, parallelism: 4 };

const isArgon2 = (h) => String(h ?? '').startsWith('$argon2');
const isBcrypt = (h) => /^\$2[aby]\$/.test(String(h ?? ''));

const hash = (plain) => argon2.hash(String(plain ?? ''), OPTIONS);

async function verify(plain, hashed) {
  const p = String(plain ?? '');
  try {
    if (isArgon2(hashed)) return await argon2.verify(hashed, p);
    if (isBcrypt(hashed)) return await bcrypt.compare(p, hashed);
  } catch {
    /* malformed hash -> just "wrong password" */
  }
  return false;
}

/** true when a stored hash should be replaced (old bcrypt, or weaker argon2 settings) */
const needsRehash = (hashed) => !isArgon2(hashed) || argon2.needsRehash(hashed, OPTIONS);

/** same rules and messages as AppStore._checkNewPassword */
function checkNewPassword(password, confirm) {
  if (String(password ?? '').length < 8) return 'Password must be at least 8 characters';
  if (password !== confirm) return 'Passwords do not match';
  return null;
}

module.exports = { hash, verify, needsRehash, checkNewPassword };
