import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { validateMap, withElevatorOutage } from '../src/core/map.js';
import { planRoute } from '../src/core/routing.js';
import { guidanceSteps, moveStep } from '../src/core/guidance.js';
import { defaults, loadSettings, saveSettings, SETTINGS_KEY } from '../src/core/settings.js';
import { ProximityPolicy } from '../src/core/proximity.js';

const map = JSON.parse(
  await readFile(new URL('../../UBAccessNavigator/Resources/demo_map.json', import.meta.url)),
);
const ids = (route) => route.legs.map((leg) => leg.connection.id);

test('shared native map is valid and contains the complete fictional graph', () => {
  assert.deepEqual(validateMap(map), []);
  assert.equal(map.landmarks.length, 12);
  assert.equal(map.connections.length, 14);
  assert.equal(map.dataStatus, 'fictional_demo');
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
test('step-free route uses confirmed ramp and elevator, with honest distance totals', () => {
  const route = planRoute(map, 'plaza', 'room-201', true);
  assert.deepEqual(ids(route), [
    'west-ramp',
    'lobby-doors',
    'main-corridor',
    'east-to-elevator',
    'elevator-a',
    'f2-elevator-to-central',
    'central-to-room-201',
  ]);
  assert.equal(route.usesStairs, false);
  assert.equal(route.recordedLengthMeters, 87);
  assert.equal(route.legsWithUnknownLength, 1);
});
test('elevator outage explains failure without offering a stairs fallback', () => {
  const changed = withElevatorOutage(map, true);
  const failure = planRoute(changed, 'plaza', 'room-201', true);
  assert.equal(failure.ok, false);
  assert.equal(failure.reason, 'unavailable');
  assert.deepEqual(
    failure.blockers.map((c) => c.id),
    ['elevator-a'],
  );
  assert.match(failure.explanation, /Elevator A \(unavailable\)/);
  assert.equal(failure.legs, undefined);
  assert.equal(planRoute(changed, 'plaza', 'room-201').ok, true);
  assert.equal(map.connections.find((c) => c.id === 'elevator-a').availability, 'available');
});
test('unknown step-free status blocks the skybridge and identifies only that blocker', () => {
  const failure = planRoute(map, 'plaza', 'annex-reading-room', true);
  assert.equal(failure.reason, 'step_free');
  assert.deepEqual(
    failure.blockers.map((c) => c.id),
    ['annex-skybridge'],
  );
  assert.match(failure.explanation, /step-free suitability unknown/);
});
test('skybridge route carries availability and suitability warnings', () => {
  const route = planRoute(map, 'plaza', 'annex-reading-room');
  assert.equal(route.ok, true);
  assert.equal(route.warnings.length, 2);
  assert.match(route.warnings[0], /availability is not confirmed/);
  assert.match(route.warnings[1], /suitability is unknown/);
});
test('exit-only connection is never traversed in reverse', () => {
  assert.deepEqual(ids(planRoute(map, 'room-105', 'plaza', true)), [
    'east-to-room-105',
    'east-exit-door',
  ]);
  assert.deepEqual(ids(planRoute(map, 'plaza', 'room-105', true)), [
    'west-ramp',
    'lobby-doors',
    'main-corridor',
    'east-to-room-105',
  ]);
});
test('reverse travel uses the authored reverse instructions', () => {
  const route = planRoute(map, 'room-201', 'room-105', true);
  const lift = route.legs.find((leg) => leg.connection.id === 'elevator-a');
  assert.equal(lift.reversed, true);
  assert.match(lift.instruction, /select Floor 1/);
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
test('combined blockers are explained without exposing the diagnostic route', () => {
  const changed = withElevatorOutage(map, true);
  changed.connections = changed.connections.filter((c) => c.type !== 'stairs');
  const failure = planRoute(changed, 'plaza', 'annex-reading-room', true);
  assert.equal(failure.reason, 'both');
  assert.equal(failure.legs, undefined);
  assert.ok(failure.blockers.some((c) => c.id === 'annex-skybridge'));
});
test('routing cost, rather than physical length, decides the route', () => {
  const changed = structuredClone(map);
  changed.connections.find((c) => c.id === 'front-steps').routingCost = 100;
  assert.equal(ids(planRoute(changed, 'plaza', 'main-entrance'))[0], 'west-ramp');
});
test('planner rejects stairs even if data incorrectly claims confirmed suitability', () => {
  const changed = structuredClone(map);
  changed.connections
    .filter((c) => c.type === 'stairs')
    .forEach((c) => {
      c.stepFree = 'confirmed';
    });
  assert.equal(planRoute(changed, 'plaza', 'room-201', true).usesStairs, false);
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
    'false step-free claim',
    (m) => {
      m.connections[0].stepFree = 'confirmed';
    },
    /stairs but claims/,
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
  const route = planRoute(map, 'plaza', 'room-201', true);
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
    saveSettings(storage, { ...defaults, requireStepFree: true, nearbyAudioAlerts: true }),
    true,
  );
  assert.equal(loadSettings(storage).requireStepFree, true);
  assert.equal(loadSettings(storage).nearbyAudioAlerts, true);
  assert.equal(loadSettings(storage).spokenDirections, false);
  store.set(SETTINGS_KEY, '{"requireStepFree":"false","nearbyAlertDistance":-1}');
  assert.deepEqual(loadSettings(storage), defaults);
  store.set(SETTINGS_KEY, '{invalid');
  assert.deepEqual(loadSettings(storage), defaults);
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

test('every selectable route obeys constraints in normal and outage conditions', () => {
  // Exhaustive demo-graph coverage catches interactions beyond the named examples.
  for (const outage of [false, true])
    for (const stepFree of [false, true]) {
      const changed = withElevatorOutage(map, outage);
      for (const start of map.landmarks.filter((l) => l.canStartHere))
        for (const end of map.landmarks.filter((l) => l.isDestination)) {
          const route = planRoute(changed, start.id, end.id, stepFree);
          if (!route.ok) continue;
          let previous = start.id;
          for (const leg of route.legs) {
            assert.equal(leg.from.id, previous);
            assert.notEqual(leg.connection.availability, 'unavailable');
            assert.ok(leg.instruction.length > 0);
            if (stepFree) {
              assert.equal(leg.connection.stepFree, 'confirmed');
              assert.notEqual(leg.connection.type, 'stairs');
            }
            if (leg.reversed) assert.equal(leg.connection.direction, 'bidirectional');
            previous = leg.to.id;
          }
          assert.equal(previous, end.id);
        }
    }
});
