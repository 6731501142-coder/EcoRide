jest.mock('../src/models/reportModel');
jest.mock('../src/models/rideModel');
jest.mock('../src/models/topupModel');
jest.mock('../src/models/feedbackModel');
jest.mock('../src/models/creditModel');
const reportModel = require('../src/models/reportModel');
const rideModel = require('../src/models/rideModel');
const topupModel = require('../src/models/topupModel');
const feedbackModel = require('../src/models/feedbackModel');
const creditModel = require('../src/models/creditModel');
const c = require('../src/controllers/adminReportsController');
const { run, fails, rideRow, admin } = require('./helpers');

const user = admin();
beforeEach(() => jest.resetAllMocks());

describe('sortReports (AppStore.reports order)', () => {
  test('urgent open first, other open next, resolved last; newest first inside a group', () => {
    const list = [
      { report_id: 1, status: 'resolved', is_urgent: false, created_at: '2026-11-10 10:00:00' },
      { report_id: 2, status: 'open', is_urgent: false, created_at: '2026-11-09 10:00:00' },
      { report_id: 3, status: 'open', is_urgent: true, created_at: '2026-11-08 10:00:00' },
      { report_id: 4, status: 'in_progress', is_urgent: false, created_at: '2026-11-10 09:00:00' },
      { report_id: 5, status: 'resolved', is_urgent: true, created_at: '2026-11-11 10:00:00' },
    ];
    expect(c.sortReports(list).map((r) => r.report_id)).toEqual([3, 4, 2, 5, 1]);
  });
  test('does not mutate the input', () => {
    const list = [{ status: 'resolved', created_at: 'a' }, { status: 'open', created_at: 'b' }];
    c.sortReports(list);
    expect(list[0].status).toBe('resolved');
  });
});

describe('sortFeedback', () => {
  test('unresolved first, newest first', () => {
    const list = [
      { feedback_id: 1, status: 'resolved', created_at: '2026-11-11' },
      { feedback_id: 2, status: 'open', created_at: '2026-11-01' },
      { feedback_id: 3, status: 'read', created_at: '2026-11-05' },
    ];
    expect(c.sortFeedback(list).map((f) => f.feedback_id)).toEqual([3, 2, 1]);
  });
});

test('listReports sorts and makes is_urgent boolean', async () => {
  reportModel.listAll.mockResolvedValue([
    { report_id: 1, status: 'open', is_urgent: 0, created_at: '2026-11-10' },
    { report_id: 2, status: 'open', is_urgent: 1, created_at: '2026-11-09' },
  ]);
  const { body } = await run(c.listReports, { user });
  expect(body.map((r) => [r.report_id, r.is_urgent])).toEqual([[2, true], [1, false]]);
});

describe('setReportStatus', () => {
  beforeEach(() => reportModel.findById.mockResolvedValue({ report_id: 4, status: 'open', is_urgent: 0 }));
  test.each(['open', 'in_progress', 'resolved'])('%s ok', async (status) => {
    await run(c.setReportStatus, { user, params: { id: '4' }, body: { status } });
    expect(reportModel.setStatus).toHaveBeenCalledWith(4, status);
  });
  test('bad status -> 400, unknown report -> 404', async () => {
    expect(await fails(c.setReportStatus, { user, params: { id: '4' }, body: { status: 'closed' } })).toMatchObject({ status: 400 });
    reportModel.findById.mockResolvedValue(null);
    expect(await fails(c.setReportStatus, { user, params: { id: '4' }, body: { status: 'open' } })).toMatchObject({ status: 404, message: 'Report not found' });
    expect(await fails(c.setReportStatus, { user, params: { id: 'x' }, body: { status: 'open' } })).toMatchObject({ status: 404 });
  });
});

describe('listRides / listTopups', () => {
  test('open=1 uses the open list, otherwise all; is_overdue boolean', async () => {
    rideModel.listOpen.mockResolvedValue([rideRow({ is_overdue: 1 })]);
    rideModel.listAll.mockResolvedValue([rideRow(), rideRow({ ride_id: 8 })]);
    expect((await run(c.listRides, { user, query: { open: '1' } })).body).toMatchObject([{ is_overdue: true }]);
    expect((await run(c.listRides, { user, query: {} })).body).toHaveLength(2);
  });
  test('status=pending filters top-ups', async () => {
    topupModel.listPending.mockResolvedValue([{ topup_id: 1 }]);
    topupModel.listAll.mockResolvedValue([{ topup_id: 1 }, { topup_id: 2 }]);
    expect((await run(c.listTopups, { user, query: { status: 'pending' } })).body).toHaveLength(1);
    expect((await run(c.listTopups, { user, query: {} })).body).toHaveLength(2);
  });
});

test('listTransactions: all transactions with the label the app shows', async () => {
  creditModel.listAll.mockResolvedValue([{ txn_type: 'ride_payment', ride_id: 7, vehicle_code: 'EB-012' }, { txn_type: 'refund' }]);
  const { body } = await run(c.listTransactions, { user });
  expect(body.map((t) => t.label)).toEqual(['Ride · EB-012', 'Refund']);
});

describe('rejectTopup', () => {
  test('ok -> failed top-up returned', async () => {
    topupModel.findById.mockResolvedValue({ topup_id: 3, status: 'pending' });
    topupModel.markFailed.mockResolvedValue(1);
    await run(c.rejectTopup, { user, params: { id: '3' } });
    expect(topupModel.markFailed).toHaveBeenCalledWith(3);
  });
  test('missing -> 404, not pending anymore -> 409', async () => {
    topupModel.findById.mockResolvedValue(null);
    expect(await fails(c.rejectTopup, { user, params: { id: '3' } })).toMatchObject({ status: 404 });
    topupModel.findById.mockResolvedValue({ topup_id: 3, status: 'paid' });
    topupModel.markFailed.mockResolvedValue(0);
    expect(await fails(c.rejectTopup, { user, params: { id: '3' } })).toMatchObject({ status: 409 });
  });
});

describe('feedback admin', () => {
  test('list is sorted', async () => {
    feedbackModel.listAll.mockResolvedValue([
      { feedback_id: 1, status: 'resolved', created_at: '2026-11-11' },
      { feedback_id: 2, status: 'open', created_at: '2026-11-01' },
    ]);
    expect((await run(c.listFeedback, { user })).body.map((f) => f.feedback_id)).toEqual([2, 1]);
  });
  test('setFeedbackStatus', async () => {
    feedbackModel.findById.mockResolvedValue({ feedback_id: 2 });
    await run(c.setFeedbackStatus, { user, params: { id: '2' }, body: { status: 'read' } });
    expect(feedbackModel.setStatus).toHaveBeenCalledWith(2, 'read');
    expect(await fails(c.setFeedbackStatus, { user, params: { id: '2' }, body: { status: 'in_progress' } })).toMatchObject({ status: 400 });
    feedbackModel.findById.mockResolvedValue(null);
    expect(await fails(c.setFeedbackStatus, { user, params: { id: '2' }, body: { status: 'read' } })).toMatchObject({ status: 404, message: 'Feedback not found' });
  });
});
