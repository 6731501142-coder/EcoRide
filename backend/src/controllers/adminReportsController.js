// Admin > Reports tab: Issues, Rides, Top-ups, Feedback
const reportModel = require('../models/reportModel');
const rideModel = require('../models/rideModel');
const topupModel = require('../models/topupModel');
const feedbackModel = require('../models/feedbackModel');
const creditModel = require('../models/creditModel');
const { withLabel } = require('./creditController');
const { badRequest, notFound, conflict } = require('../utils/errors');
const { toInt } = require('../utils/helpers');

const REPORT_STATUS = ['open', 'in_progress', 'resolved'];
const FEEDBACK_STATUS = ['open', 'read', 'resolved'];

const asReport = (r) => ({ ...r, is_urgent: !!r.is_urgent });

/** issue order: urgent first -> still open -> newest first; resolved ones at the bottom (AppStore.reports) */
function sortReports(list) {
  const rank = (r) => (r.status === 'resolved' ? 2 : r.is_urgent ? 0 : 1);
  return [...list].sort((a, b) => rank(a) - rank(b) || String(b.created_at).localeCompare(String(a.created_at)));
}

/** unresolved feedback first, then newest first (AppStore.feedback) */
function sortFeedback(list) {
  return [...list].sort((a, b) => {
    const ra = a.status === 'resolved' ? 1 : 0;
    const rb = b.status === 'resolved' ? 1 : 0;
    return ra - rb || String(b.created_at).localeCompare(String(a.created_at));
  });
}

/** GET /admin/reports */
async function listReports(req, res) {
  res.json(sortReports((await reportModel.listAll()).map(asReport)));
}

/** PUT /admin/reports/:id/status  { status: open | in_progress | resolved } */
async function setReportStatus(req, res) {
  const id = toInt(req.params.id);
  const r = id === null ? null : await reportModel.findById(id);
  if (!r) throw notFound('Report not found');
  const status = String(req.body?.status ?? '');
  if (!REPORT_STATUS.includes(status)) throw badRequest('Status must be open, in_progress or resolved');
  await reportModel.setStatus(r.report_id, status);
  res.json(asReport(await reportModel.findById(r.report_id)));
}

/** GET /admin/rides?open=1  (open = not returned yet, overdue first) */
async function listRides(req, res) {
  const rows = req.query.open === '1' || req.query.open === 'true' ? await rideModel.listOpen() : await rideModel.listAll();
  res.json(rows.map((r) => ({ ...r, is_overdue: !!r.is_overdue })));
}

/** GET /admin/topups?status=pending */
async function listTopups(req, res) {
  const rows = req.query.status === 'pending' ? await topupModel.listPending() : await topupModel.listAll();
  res.json(rows);
}

/** GET /admin/transactions  every credit transaction (the app works out revenue / user history from it) */
async function listTransactions(req, res) {
  res.json((await creditModel.listAll()).map(withLabel));
}

/** POST /admin/topups/:id/reject  (money did not arrive -> failed) */
async function rejectTopup(req, res) {
  const id = toInt(req.params.id);
  const t = id === null ? null : await topupModel.findById(id);
  if (!t) throw notFound('Top-up not found or not pending');
  if ((await topupModel.markFailed(t.topup_id)) === 0) throw conflict('Top-up not found or not pending');
  res.json(await topupModel.findById(t.topup_id));
}

/** GET /admin/feedback */
async function listFeedback(req, res) {
  res.json(sortFeedback(await feedbackModel.listAll()));
}

/** PUT /admin/feedback/:id/status  { status: open | read | resolved } */
async function setFeedbackStatus(req, res) {
  const id = toInt(req.params.id);
  const f = id === null ? null : await feedbackModel.findById(id);
  if (!f) throw notFound('Feedback not found');
  const status = String(req.body?.status ?? '');
  if (!FEEDBACK_STATUS.includes(status)) throw badRequest('Status must be open, read or resolved');
  await feedbackModel.setStatus(f.feedback_id, status);
  res.json(await feedbackModel.findById(f.feedback_id));
}

module.exports = {
  listReports, setReportStatus, listRides, listTopups, listTransactions, rejectTopup, listFeedback, setFeedbackStatus,
  sortReports, sortFeedback,
};
