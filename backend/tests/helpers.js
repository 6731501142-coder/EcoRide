// small helpers shared by the unit tests (no real database, no real HTTP)

/** run an express handler with a fake req/res -> { status, body }, or throws what the handler throws */
async function run(handler, { body = {}, params = {}, query = {}, user = null, headers = {} } = {}) {
  const out = { status: 200, body: undefined };
  const res = {
    status(code) { out.status = code; return this; },
    json(data) { out.body = data; return this; },
  };
  await handler({ body, params, query, user, headers }, res);
  return out;
}

/** run a handler and return the AppError it throws (fails the test if nothing is thrown) */
async function fails(handler, req) {
  let thrown;
  try {
    await run(handler, req);
  } catch (e) {
    thrown = e;
  }
  if (!thrown) throw new Error('expected the handler to throw, but it did not');
  return thrown;
}

/** a vehicles row as vehicleModel returns it (battery 79 %, parked at station 1, just charged) */
const vehicleRow = (o = {}) => ({
  vehicle_id: 1, vehicle_code: 'EB-012', type_id: 1, code_prefix: 'EB', type_name: 'Electric bicycle',
  current_station_id: 1, station_name: 'Building 1', battery_level: 79, battery_updated_at: '2026-11-10 18:29:44',
  status: 'available', seconds_since_battery_update: 0, open_ride_id: null, ride_battery_start: null, ride_used_seconds: null,
  ...o,
});

const scooterRow = (o = {}) => vehicleRow({ vehicle_id: 3, vehicle_code: 'ES-031', type_id: 2, code_prefix: 'ES', type_name: 'Electric scooter', ...o });

const student = (o = {}) => ({
  user_id: 1, student_id: '6731501118', username: 'somchai.j', full_name: 'Somchai Jaidee', avatar_id: null,
  avatar_url: null, role: 'student', credit_balance: 150, is_active: 1, created_at: '2026-11-08 01:13:18', updated_at: '2026-11-08 01:13:18', ...o,
});

const admin = (o = {}) => student({ user_id: 2, student_id: 'ADMIN0001', username: 'admin', full_name: 'EcoRide Admin', role: 'admin', credit_balance: 0, ...o });

const rideRow = (o = {}) => ({
  ride_id: 7, user_id: 1, vehicle_id: 1, plan_id: 1, start_station_id: 1, return_station_id: null,
  start_time: '2026-11-11 09:00:00', due_time: '2026-11-12 09:00:00', end_time: null, battery_start: 79, battery_end: null,
  price_paid: 100, status: 'active', vehicle_code: 'EB-012', code_prefix: 'EB', vehicle_type: 'Electric bicycle',
  from_station: 'Building 1', return_station: null, duration_min: 5, is_overdue: 0, ...o,
});

const station = (o = {}) => ({
  station_id: 1, name: 'Building 1', total_docks: 10, icon_key: 'building', photo_url: null, latitude: null, longitude: null, is_active: 1, ...o,
});

module.exports = { run, fails, vehicleRow, scooterRow, student, admin, rideRow, station };
