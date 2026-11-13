const { AppError, mapDbError } = require('../utils/errors');

const notFoundHandler = (req, res) => res.status(404).json({ error: 'Route not found' });

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const e = mapDbError(err);
  if (e instanceof AppError) return res.status(e.status).json({ error: e.message });

  // body-parser problems
  if (err && err.type === 'entity.parse.failed') return res.status(400).json({ error: 'Invalid JSON' });
  if (err && err.type === 'entity.too.large') return res.status(413).json({ error: 'Request is too large' });

  console.error(err);
  return res.status(500).json({ error: 'Internal server error' });
}

module.exports = { errorHandler, notFoundHandler };
