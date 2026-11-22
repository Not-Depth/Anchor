import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { validateMap } from '../src/core/map.js';
import { planRoute } from '../src/core/routing.js';
import { guidanceSteps, moveStep } from '../src/core/guidance.js';
import { defaults, loadSettings, saveSettings, SETTINGS_KEY } from '../src/core/settings.js';
import { ProximityPolicy } from '../src/core/proximity.js';

const mapSource = await readFile(
  new URL('../../UBAccessNavigator/Resources/demo_map.json', import.meta.url),
  'utf8',
);
const map = JSON.parse(mapSource);
const ids = (route) => route.legs.map((leg) => leg.connection.id);
// A copy of the map with some connections closed, e.g. a stairwell under repair.
const closing = (closedIDs) => ({
  ...map,
  connections: map.connections.map((c) =>
    closedIDs.includes(c.id) ? { ...c, availability: 'unavailable' } : c,
  ),
});

test('shared native map is valid and contains the complete fictional graph', () => {
  assert.deepEqual(validateMap(map), []);
  assert.equal(map.landmarks.length, 12);
  assert.equal(map.connections.length, 14);
  assert.equal(map.dataStatus, 'fictional_demo');
});
test('shared map carries no wheelchair-only step-free fields', () => {
  assert.equal(mapSource.includes('stepFree'), false);
  assert.equal(/step-free/i.test(mapSource), false);
});
test('default shortest route matches the native test scenario and cost', () => {
  const route = planRoute(map, 'plaza', 'room-201');
  assert.deepEqual(ids(route), [
    'front-steps',
    'lobby-doors',
    'west-to-stairwell',
    'stairwell-a-stairs',
    'f2-stairwell-to-central',
    'central-to-room-201',
  ]);
  assert.equal(route.totalRoutingCost, 47);
  assert.equal(route.usesStairs, true);
});
test('a closed stairwell reroutes through the elevator, with honest distance totals', () => {
  const route = planRoute(closing(['stairwell-a-stairs']), 'plaza', 'room-201');
  assert.deepEqual(ids(route), [
    'front-steps',
    'lobby-doors',
    'main-corridor',
    'east-to-elevator',
    'elevator-a',
    'f2-elevator-to-central',
    'central-to-room-201',
  ]);
  assert.equal(route.recordedLengthMeters, 75);
  assert.equal(route.legsWithUnknownLength, 1);
});
test('closing every way upstairs explains the blocker without offering a route', () => {
  const failure = planRoute(closing(['stairwell-a-stairs', 'elevator-a']), 'plaza', 'room-201');
  assert.equal(failure.ok, false);
  assert.equal(failure.reason, 'unavailable');
  assert.deepEqual(
    failure.blockers.map((c) => c.id),
    ['stairwell-a-stairs'],
  );
  assert.match(failure.explanation, /Stairwell A stairs \(unavailable\)/);
  assert.equal(failure.legs, undefined);
  assert.equal(map.connections.find((c) => c.id === 'elevator-a').availability, 'available');
});
test('skybridge route carries only the availability warning', () => {
  const route = planRoute(map, 'plaza', 'annex-reading-room');
  assert.equal(route.ok, true);
  assert.deepEqual(route.warnings, ['Skybridge to Annex: current availability is not confirmed.']);
});
test('exit-only connection is never traversed in reverse', () => {
  assert.deepEqual(ids(planRoute(map, 'room-105', 'plaza')), [
    'east-to-room-105',
    'east-exit-door',
  ]);
  assert.deepEqual(ids(planRoute(map, 'plaza', 'room-105')), [
    'front-steps',
    'lobby-doors',
    'main-corridor',
    'east-to-room-105',
  ]);
});
test('reverse travel uses the authored reverse instructions', () => {
  const route = planRoute(map, 'room-201', 'room-105');
  const stairs = route.legs.find((leg) => leg.connection.id === 'stairwell-a-stairs');
  assert.equal(stairs.reversed, true);
  assert.match(stairs.instruction, /Go down the stairs to Floor 1/);
});
test('same location, unknown IDs and disconnected places have distinct failures', () => {
  assert.equal(planRoute(map, 'plaza', 'plaza').reason, 'same_location');
  assert.equal(planRoute(map, 'missing', 'plaza').reason, 'unknown_landmark');
  const disconnected = structuredClone(map);
  disconnected.connections = disconnected.connections.filter(
    (c) => ![c.from, c.to].includes('room-201'),
  );
  assert.equal(planRoute(disconnected, 'plaza', 'room-201').reason, 'not_connected');
});
test('routing cost, rather than physical length, decides the route', () => {
  const changed = structuredClone(map);
  changed.connections.find((c) => c.id === 'front-steps').routingCost = 100;
  assert.equal(ids(planRoute(changed, 'plaza', 'main-entrance'))[0], 'west-ramp');
});

for (const [name, mutate, match] of [
  ['duplicate IDs', (m) => m.landmarks.push(m.landmarks[0]), /Duplicate/],
  [
    'missing connection fields',
    (m) => {
      delete m.connections[0].id;
    },
    /id and name/,
  ],
  [
    'invalid endpoint',
    (m) => {
      m.connections[0].to = 'missing';
    },
    /unknown landmark/,
  ],
  [
    'missing cost',
    (m) => {
      delete m.connections[0].lengthMeters;
    },
    /positive routing cost/,
  ],
  [
    'negative cost',
    (m) => {
      m.connections[0].routingCost = -1;
    },
    /invalid routing cost/,
  ],
  [
    'zero cost',
    (m) => {
      m.connections[0].lengthMeters = 0;
    },
    /positive routing cost/,
  ],
  [
    'missing reverse direction',
    (m) => {
      delete m.connections[0].instructions.reverse;
    },
    /reverse instruction/,
  ],
  [
    'false verification claim',
    (m) => {
      m.connections[0].verification.status = 'verified';
    },
    /mixes simulated/,
  ],
  [
    'unknown availability',
    (m) => {
      m.connections[0].availability = 'maybe';
    },
    /invalid availability/,
  ],
  [
    'missing disclaimer',
    (m) => {
      m.disclaimer = '';
    },
    /disclaimer/,
  ],
  [
    'invalid schematic',
    (m) => {
      m.landmarks[0].schematic.x = 2;
    },
    /Invalid schematic/,
  ],
])
  test(`validation rejects ${name}`, () => {
    const changed = structuredClone(map);
    mutate(changed);
    assert.match(validateMap(changed).join(' '), match);
  });
test('validation handles malformed map shapes without throwing', () => {
  for (const value of [
    null,
    {},
    [],
    { ...map, connections: null },
    { ...map, connections: [null] },
  ])
    assert.ok(validateMap(value).length);
});
test('guidance confirms start, every leg, and arrival without going out of bounds', () => {
  const route = planRoute(map, 'plaza', 'room-201');
  const steps = guidanceSteps(route);
  assert.equal(steps.length, route.legs.length + 2);
  assert.equal(steps[0].landmarkID, 'plaza');
  assert.equal(steps[1].instruction, route.legs[0].instruction);
  assert.equal(steps[1].cue, route.legs[0].to.arrivalCue);
  assert.equal(steps.at(-1).confirm, null);
  assert.equal(moveStep(0, -1, steps), 0);
  assert.equal(moveStep(steps.length - 1, 1, steps), steps.length - 1);
});
test('settings persist independently and invalid stored types are discarded', () => {
  const store = new Map();
  const storage = {
    getItem: (key) => store.get(key),
    setItem: (key, value) => store.set(key, value),
  };
  assert.equal(
    saveSettings(storage, { ...defaults, nearbyHapticAlerts: true, nearbyAudioAlerts: true }),
    true,
  );
  assert.equal(loadSettings(storage).nearbyHapticAlerts, true);
  assert.equal(loadSettings(storage).nearbyAudioAlerts, true);
  assert.equal(loadSettings(storage).spokenDirections, false);
  store.set(SETTINGS_KEY, '{"nearbyHapticAlerts":"false","nearbyAlertDistance":-1}');
  assert.deepEqual(loadSettings(storage), defaults);
  store.set(SETTINGS_KEY, '{invalid');
  assert.deepEqual(loadSettings(storage), defaults);
});
test('step-free settings saved by older versions are ignored', () => {
  const store = new Map([
    [
      SETTINGS_KEY,
      '{"requireStepFree":true,"simulateElevatorOutage":true,"spokenDirections":true}',
    ],
  ]);
  const settings = loadSettings({ getItem: (key) => store.get(key) });
  assert.equal('requireStepFree' in settings, false);
  assert.equal('simulateElevatorOutage' in settings, false);
  assert.equal(settings.spokenDirections, true);
});
test('denied browser storage is nonfatal', () => {
  const storage = {
    getItem() {
      throw new Error('denied');
    },
    setItem() {
      throw new Error('denied');
    },
  };
  assert.deepEqual(loadSettings(storage), defaults);
  assert.equal(saveSettings(storage, defaults), false);
});
test('proximity alerts throttle repeats and use hysteresis before rearming', () => {
  const policy = new ProximityPolicy(1);
  assert.equal(policy.update(0.9, 0), 'near');
  assert.equal(policy.update(1.05, 100), null);
  assert.equal(policy.update(0.9, 2999), null);
  assert.equal(policy.update(0.9, 3000), 'near');
  assert.equal(policy.update(1.3, 3100), null);
  assert.equal(policy.update(0.9, 3200), 'near');
});
test('lost readings get a grace period, one warning and a recovery event', () => {
  const policy = new ProximityPolicy(1);
  assert.equal(policy.update(null, 0), null);
  policy.update(2, 10);
  assert.equal(policy.update(null, 20), null);
  assert.equal(policy.update(null, 1019), null);
  assert.equal(policy.update(null, 1020), 'unreliable');
  assert.equal(policy.update(null, 5000), null);
  assert.equal(policy.update(0.5, 5010), 'restored');
  assert.equal(policy.update(0.5, 5020), 'near');
});

test('every selectable route obeys constraints, including with the stairwell closed', () => {
  // Exhaustive demo-graph coverage catches interactions beyond the named examples.
  for (const changed of [map, closing(['stairwell-a-stairs'])])
    for (const start of map.landmarks.filter((l) => l.canStartHere))
      for (const end of map.landmarks.filter((l) => l.isDestination)) {
        const route = planRoute(changed, start.id, end.id);
        if (!route.ok) continue;
        let previous = start.id;
        for (const leg of route.legs) {
          assert.equal(leg.from.id, previous);
          assert.notEqual(leg.connection.availability, 'unavailable');
          assert.ok(leg.instruction.length > 0);
          if (leg.reversed) assert.equal(leg.connection.direction, 'bidirectional');
          previous = leg.to.id;
        }
        assert.equal(previous, end.id);
      }
});
