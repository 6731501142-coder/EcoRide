const express = require('express');
const { authenticate, requireAdmin } = require('../middleware/auth');
const { asyncHandler: h } = require('../utils/helpers');

const auth = require('../controllers/authController');
const account = require('../controllers/accountController');
const catalog = require('../controllers/catalogController');
const rides = require('../controllers/rideController');
const credit = require('../controllers/creditController');
const feedback = require('../controllers/feedbackController');
const adminOverview = require('../controllers/adminOverviewController');
const adminStations = require('../controllers/adminStationController');
const adminVehicles = require('../controllers/adminVehicleController');
const adminReports = require('../controllers/adminReportsController');
const adminUsers = require('../controllers/adminUserController');

const router = express.Router();

router.get('/health', (req, res) => res.json({ ok: true }));

// ---- public (no token) ----------------------------------------------------
router.post('/auth/login', h(auth.login));
router.post('/auth/register', h(auth.register));
router.post('/auth/find-username', h(auth.findUsername));
router.post('/auth/reset-password', h(auth.resetPassword));

// ---- everything below needs a logged-in user --------------------------------
router.use(authenticate);

// profile
router.get('/me', h(account.getMe));
router.put('/me', h(account.updateProfile));
router.put('/me/password', h(account.changePassword));
router.put('/me/avatar', h(account.setPresetAvatar));
router.post('/me/avatar/photo', h(account.uploadAvatar));
router.delete('/me/avatar', h(account.removeAvatar));

// stations / vehicles / plans
router.get('/stations', h(catalog.listStations));
router.get('/stations/:id/vehicles', h(catalog.vehiclesAtStation));
router.get('/vehicles', h(catalog.listVehicles));
router.get('/vehicles/by-code/:code', h(catalog.vehicleByCode));
router.get('/vehicle-types', h(catalog.listTypes));
router.get('/rental-plans', h(catalog.listPlans));

// rides
router.get('/rides/active', h(rides.activeRide));
router.get('/rides/stats', h(rides.myStats));
router.get('/rides', h(rides.myRides));
router.post('/rides', h(rides.borrow));
router.post('/rides/:id/return', h(rides.returnVehicle));
router.post('/rides/:id/help', h(rides.requestHelp));

// credit
router.get('/credit/transactions', h(credit.myTransactions));
router.post('/topups', h(credit.createTopup));
router.post('/topups/:id/confirm', h(credit.confirmTopup));

// feedback
router.post('/feedback', h(feedback.submit));

// ---- admin only -----------------------------------------------------------
const admin = express.Router();
admin.use(requireAdmin);

admin.get('/overview', h(adminOverview.overview));

admin.get('/stations', h(adminStations.list));
admin.post('/stations', h(adminStations.create));
admin.put('/stations/:id', h(adminStations.update));
admin.post('/stations/:id/photo', h(adminStations.uploadPhoto));
admin.delete('/stations/:id/photo', h(adminStations.removePhoto));

admin.get('/vehicles', h(adminVehicles.list));
admin.post('/vehicles', h(adminVehicles.add));
admin.put('/vehicles/:id/maintenance', h(adminVehicles.setMaintenance));

admin.get('/reports', h(adminReports.listReports));
admin.put('/reports/:id/status', h(adminReports.setReportStatus));
admin.get('/rides', h(adminReports.listRides));
admin.get('/topups', h(adminReports.listTopups));
admin.get('/transactions', h(adminReports.listTransactions));
admin.post('/topups/:id/confirm', h(credit.confirmTopup));
admin.post('/topups/:id/reject', h(adminReports.rejectTopup));
admin.get('/feedback', h(adminReports.listFeedback));
admin.put('/feedback/:id/status', h(adminReports.setFeedbackStatus));

admin.get('/users', h(adminUsers.list));
admin.get('/users/:id', h(adminUsers.detail));
admin.put('/users/:id', h(adminUsers.update));
admin.put('/users/:id/active', h(adminUsers.setActive));
admin.post('/users/:id/credit', h(adminUsers.adjustCredit));

router.use('/admin', admin);

module.exports = router;
