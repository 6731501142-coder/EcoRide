const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

/** trim a value that should be text; anything else becomes '' */
const str = (v) => (typeof v === 'string' ? v.trim() : v == null ? '' : String(v).trim());

/** strict integer parse: "12" -> 12, "12abc" / 1.5 / null -> null */
function toInt(v) {
  if (typeof v === 'number') return Number.isInteger(v) ? v : null;
  if (typeof v === 'string' && /^-?\d+$/.test(v.trim())) return Number(v.trim());
  return null;
}

const bool = (v) => v === true || v === 1 || v === '1' || v === 'true';

/** MariaDB returns TINYINT(1) as 0/1 -> real booleans for the JSON the app reads */
const withBools = (row, keys) => {
  if (!row) return row;
  const out = { ...row };
  for (const k of keys) if (k in out) out[k] = !!out[k];
  return out;
};

module.exports = { asyncHandler, str, toInt, bool, withBools };
