jest.mock('../src/models/vehicleModel');
jest.mock('../src/models/stationModel');
jest.mock('../src/models/rideModel');
jest.mock('../src/models/reportModel');
jest.mock('../src/models/topupModel');
jest.mock('../src/models/creditModel');
jest.mock('../src/models/feedbackModel');
const vehicleModel = require('../src/models/vehicleModel');
const stationModel = require('../src/models/stationModel');
const rideModel = require('../src/models/rideModel');
const reportModel = require('../src/models/reportModel');
const topupModel = require('../src/models/topupModel');
const creditModel = require('../src/models/creditModel');
const feedbackModel = require('../src/models/feedbackModel');
const { overview } = require('../src/controllers/adminOverviewController');
const { run, vehicleRow, scooterRow, rideRow, station, admin } = require('./helpers');

beforeEach(() => {
  jest.resetAllMocks();
  vehicleModel.listAll.mockResolvedValue([
    vehicleRow({ vehicle_id: 1 }), // ready
    scooterRow({ vehicle_id: 3, battery_level: 12 }), // charging, not ready
    vehicleRow({ vehicle_id: 9, vehicle_code: 'EB-099', status: 'maintenance' }), // in repair
    vehicleRow({ vehicle_id: 8, vehicle_code: 'EB-004', status: 'in_use', current_station_id: null, ride_battery_start: 77, ride_used_seconds: 60 }),
  ]);
  stationModel.listAll.mockResolvedValue([station(), station({ station_id: 2, name: 'Building 2', is_active: 0 })]);
  rideModel.listOpen.mockResolvedValue([rideRow({ is_overdue: 1 }), rideRow({ ride_id: 8, is_overdue: 0 })]);
  reportModel.listAll.mockResolvedValue([
    { report_id: 1, is_urgent: true, status: 'open' },
    { report_id: 2, is_urgent: false, status: 'in_progress' },
    { report_id: 3, is_urgent: true, status: 'resolved' },
  ]);
  topupModel.listPending.mockResolvedValue([{ topup_id: 5 }]);
  feedbackModel.countOpen.mockResolvedValue(2);
  creditModel.revenueThisMonth.mockResolvedValue(400);
  topupModel.paidThisMonth.mockResolvedValue(900);
});

test('KPI numbers (same as the Overview tab)', async () => {
  const { body } = await run(overview, { user: admin() });
  expect(body.kpi).toEqual({
    riding_now: 2, overdue: 1, open_issues: 2, revenue_this_month: 400, topups_this_month: 900,
    ready: 1, charging: 2, in_repair: 1,
  });
});
test('"needs attention" lists: urgent first, resolved issues are left out', async () => {
  const { body } = await run(overview, { user: admin() });
  expect(body.attention.urgent_reports.map((r) => r.report_id)).toEqual([1]);
  expect(body.attention.other_issues.map((r) => r.report_id)).toEqual([2]);
  expect(body.attention.overdue_rides.map((r) => r.ride_id)).toEqual([7]);
  expect(body.attention.pending_topups).toHaveLength(1);
  expect(body.attention.unread_feedback).toBe(2);
});
test('badge = open issues + pending top-ups + unread feedback', async () => {
  expect((await run(overview, { user: admin() })).body.badge).toBe(2 + 1 + 2);
});
test('stations include closed ones, with availability', async () => {
  const { body } = await run(overview, { user: admin() });
  expect(body.stations).toHaveLength(2);
  expect(body.stations[0]).toMatchObject({ station_id: 1, vehicles_docked: 3, free_docks: 7 });
  expect(body.stations[1].is_active).toBe(false);
});
test('everything empty -> zeros', async () => {
  vehicleModel.listAll.mockResolvedValue([]);
  stationModel.listAll.mockResolvedValue([]);
  rideModel.listOpen.mockResolvedValue([]);
  reportModel.listAll.mockResolvedValue([]);
  topupModel.listPending.mockResolvedValue([]);
  feedbackModel.countOpen.mockResolvedValue(0);
  const { body } = await run(overview, { user: admin() });
  expect(body.badge).toBe(0);
  expect(body.kpi).toMatchObject({ riding_now: 0, ready: 0, charging: 0 });
});
