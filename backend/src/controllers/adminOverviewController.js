// Admin > Overview  (= the numbers and "needs attention" list on the Overview tab)
const vehicleModel = require('../models/vehicleModel');
const stationModel = require('../models/stationModel');
const rideModel = require('../models/rideModel');
const reportModel = require('../models/reportModel');
const topupModel = require('../models/topupModel');
const creditModel = require('../models/creditModel');
const feedbackModel = require('../models/feedbackModel');
const vs = require('../services/vehicleService');

const asRide = (r) => ({ ...r, is_overdue: !!r.is_overdue });
const asReport = (r) => ({ ...r, is_urgent: !!r.is_urgent });

/** GET /admin/overview */
async function overview(req, res) {
  const [vehicleRows, stations, openRides, reports, pending, unreadFeedback, revenue, topups] = await Promise.all([
    vehicleModel.listAll(),
    stationModel.listAll(),
    rideModel.listOpen(),
    reportModel.listAll(),
    topupModel.listPending(),
    feedbackModel.countOpen(),
    creditModel.revenueThisMonth(),
    topupModel.paidThisMonth(),
  ]);

  const vehicles = vehicleRows.map((v) => vs.decorate(v));
  const rides = openRides.map(asRide);
  const openReports = reports.map(asReport).filter((r) => r.status !== 'resolved');
  const docked = vehicles.filter((v) => v.current_station_id != null);

  res.json({
    kpi: {
      riding_now: rides.length,
      overdue: rides.filter((r) => r.is_overdue).length,
      open_issues: openReports.length,
      revenue_this_month: revenue,
      topups_this_month: topups,
      ready: vehicles.filter((v) => v.can_borrow).length,
      charging: vehicles.filter((v) => v.is_charging).length,
      in_repair: vehicles.filter((v) => v.status === 'maintenance').length,
    },
    attention: {
      urgent_reports: openReports.filter((r) => r.is_urgent),
      overdue_rides: rides.filter((r) => r.is_overdue),
      pending_topups: pending,
      other_issues: openReports.filter((r) => !r.is_urgent),
      unread_feedback: unreadFeedback,
    },
    // red dot on the Reports tab: open issues + pending top-ups + unread feedback
    badge: openReports.length + pending.length + unreadFeedback,
    stations: stations.map((s) => vs.withAvailability(s, docked)),
  });
}

module.exports = { overview };
