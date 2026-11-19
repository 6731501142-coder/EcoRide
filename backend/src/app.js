const express = require('express');
const cors = require('cors');
const config = require('./config');
const routes = require('./routes');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

const app = express();

app.use(cors({ origin: config.corsOrigin }));
app.use(express.json({ limit: '4mb' })); // photos are sent as base64 (max 2 MB image ≈ 2.7 MB text)
app.use('/uploads', express.static(config.uploadDir)); // profile / station photos

app.use('/api', routes);

app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
