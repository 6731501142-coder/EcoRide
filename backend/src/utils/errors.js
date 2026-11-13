class AppError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'AppError';
    this.status = status;
  }
}

const badRequest = (m) => new AppError(400, m);
const unauthorized = (m) => new AppError(401, m);
const forbidden = (m) => new AppError(403, m);
const notFound = (m) => new AppError(404, m);
const conflict = (m) => new AppError(409, m);

/**
 * Turn a database error into an AppError.
 *  - SIGNAL SQLSTATE '45000' from the stored procedures -> 409 with the procedure's own message
 *  - duplicate key (username / student_id / vehicle_code / station name) -> 409
 * Anything else is returned unchanged (the error handler will turn it into a 500).
 */
function mapDbError(err) {
  if (err instanceof AppError) return err;
  if (err && err.sqlState === '45000') return new AppError(409, err.sqlMessage || err.message);
  if (err && (err.code === 'ER_DUP_ENTRY' || err.errno === 1062)) {
    const m = String(err.sqlMessage || err.message || '');
    if (m.includes('uq_users_username')) return conflict('Username is already taken');
    if (m.includes('uq_users_student_id')) return conflict('Student ID is already registered');
    if (m.includes('uq_vehicles_code')) return conflict('This vehicle code already exists');
    if (m.includes('uq_stations_name')) return conflict('This name is already used');
    return conflict('Duplicate value');
  }
  return err;
}

module.exports = { AppError, badRequest, unauthorized, forbidden, notFound, conflict, mapDbError };
