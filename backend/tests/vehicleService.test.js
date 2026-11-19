const vs = require('../src/services/vehicleService');
const { vehicleRow, scooterRow, station } = require('./helpers');

const ts = { timeScale: 1 };

describe('decorate', () => {
  test('adds live fields and keeps the DB column names the app reads', () => {
    expect(vs.decorate(vehicleRow({ battery_level: 79 }), ts)).toMatchObject({
      vehicle_id: 1, vehicle_code: 'EB-012', type_id: 1, current_station_id: 1, battery_level: 79,
      status: 'available', live_battery: 79, can_borrow: true, is_charging: true, minutes_until_ready: null,
      station_name: 'Building 1', code_prefix: 'EB',
    });
  });
  test('does not leak the internal columns', () => {
    const d = vs.decorate(vehicleRow(), ts);
    expect(d).not.toHaveProperty('seconds_since_battery_update');
    expect(d).not.toHaveProperty('ride_used_seconds');
  });
  test('low battery parked vehicle: cannot borrow, says when it will be ready', () => {
    const d = vs.decorate(scooterRow({ battery_level: 12 }), ts);
    expect(d).toMatchObject({ can_borrow: false, is_charging: true, minutes_until_ready: 15 });
  });
  test('vehicle in use is never borrowable and not charging', () => {
    const d = vs.decorate(vehicleRow({ status: 'in_use', current_station_id: null, station_name: null, ride_battery_start: 90, ride_used_seconds: 3600 }), ts);
    expect(d).toMatchObject({ can_borrow: false, is_charging: false, live_battery: 79, station_name: null });
  });
});

describe('sortForStation', () => {
  test('borrowable first, then fullest battery first', () => {
    const list = [
      vs.decorate(scooterRow({ vehicle_id: 3, battery_level: 12 }), ts),
      vs.decorate(vehicleRow({ vehicle_id: 1, battery_level: 79 }), ts),
      vs.decorate(vehicleRow({ vehicle_id: 4, vehicle_code: 'ES-016', battery_level: 91 }), ts),
    ];
    expect(vs.sortForStation(list).map((v) => v.vehicle_id)).toEqual([4, 1, 3]);
  });
  test('does not change the original array', () => {
    const list = [vs.decorate(scooterRow({ battery_level: 12 }), ts), vs.decorate(vehicleRow(), ts)];
    vs.sortForStation(list);
    expect(list[0].vehicle_id).toBe(3);
  });
});

describe('availability / withAvailability', () => {
  const docked = [
    vs.decorate(vehicleRow({ vehicle_id: 1, battery_level: 79 }), ts),
    vs.decorate(vehicleRow({ vehicle_id: 2, vehicle_code: 'EB-015', battery_level: 72 }), ts),
    vs.decorate(scooterRow({ vehicle_id: 3, battery_level: 12 }), ts),
    vs.decorate(scooterRow({ vehicle_id: 4, vehicle_code: 'ES-016', battery_level: 91 }), ts),
    vs.decorate(vehicleRow({ vehicle_id: 9, vehicle_code: 'EB-099', status: 'maintenance' }), ts),
  ];
  test('counts like AppStore.availability', () => {
    expect(vs.availability(station({ total_docks: 10 }), docked)).toEqual({
      vehicles_docked: 5, free_docks: 5, bikes: 3, scooters: 2,
      ready_bikes: 2, ready_scooters: 1, ready_to_ride: 3, is_full: false,
    });
  });
  test('full when no dock is free', () => {
    expect(vs.availability(station({ total_docks: 5 }), docked)).toMatchObject({ free_docks: 0, is_full: true });
    expect(vs.availability(station({ total_docks: 4 }), docked).is_full).toBe(true);
  });
  test('empty station', () => {
    expect(vs.availability(station({ total_docks: 8 }), [])).toMatchObject({ vehicles_docked: 0, free_docks: 8, ready_to_ride: 0, is_full: false });
  });
  test('withAvailability only counts that station and makes is_active a boolean', () => {
    const other = vs.decorate(vehicleRow({ vehicle_id: 20, current_station_id: 2 }), ts);
    const s = vs.withAvailability(station({ station_id: 1, is_active: 1 }), [...docked, other]);
    expect(s.vehicles_docked).toBe(5);
    expect(s.is_active).toBe(true);
    expect(s).toMatchObject({ station_id: 1, name: 'Building 1', total_docks: 10, icon_key: 'building', photo_url: null });
  });
});
