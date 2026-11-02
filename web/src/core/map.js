const nonempty = (value) => typeof value === 'string' && value.trim().length > 0;
const positive = (value) => Number.isFinite(value) && value > 0;

// Reject incomplete data before routing; skipping a broken connection can silently
// turn a data error into a misleading "no accessible route" result.
export function validateMap(map) {
  const errors = [];
  if (!map || typeof map !== 'object') return ['Map must be an object.'];
  if (map.schemaVersion !== 1) errors.push('Unsupported map schema version.');
  for (const key of ['id', 'name', 'disclaimer']) {
    if (!nonempty(map[key])) errors.push(`Map needs ${key}.`);
  }
  if (!['fictional_demo', 'surveyed_unverified', 'surveyed_verified'].includes(map.dataStatus)) {
    errors.push('Unknown map data status.');
  }
  for (const key of ['floors', 'landmarks', 'connections']) {
    if (!Array.isArray(map[key])) errors.push(`Map needs a ${key} array.`);
  }
  if (errors.length) return errors;
  for (const key of ['floors', 'landmarks', 'connections']) {
    const ids = new Set();
    for (const item of map[key]) {
      if (!item || !nonempty(item.id) || !nonempty(item.name)) {
        errors.push(`Every ${key} entry needs an id and name.`);
        continue;
      }
      if (ids.has(item.id)) errors.push(`Duplicate ${key} id: ${item.id}.`);
      ids.add(item.id);
    }
  }
  if (errors.length) return errors;
  const floors = new Set(map.floors.map((floor) => floor.id));
  const landmarks = new Set(map.landmarks.map((landmark) => landmark.id));
  if (map.floors.some((floor) => !Number.isFinite(floor.level)))
    errors.push('Floors need numeric levels.');
  for (const landmark of map.landmarks) {
    if (!floors.has(landmark.floorID)) errors.push(`Unknown floor for ${landmark.id}.`);
    if (!nonempty(landmark.arrivalCue)) errors.push(`Missing arrival cue for ${landmark.id}.`);
    if (typeof landmark.canStartHere !== 'boolean' || typeof landmark.isDestination !== 'boolean') {
      errors.push(`Invalid start/destination flags for ${landmark.id}.`);
    }
    if (
      landmark.schematic &&
      !['x', 'y'].every(
        (axis) =>
          Number.isFinite(landmark.schematic[axis]) &&
          landmark.schematic[axis] >= 0 &&
          landmark.schematic[axis] <= 1,
      )
    ) {
      errors.push(`Invalid schematic position for ${landmark.id}.`);
    }
  }
  if (!map.landmarks.some((item) => item.canStartHere)) errors.push('No starting landmarks.');
  if (!map.landmarks.some((item) => item.isDestination)) errors.push('No destinations.');
  for (const c of map.connections) {
    const label = `Connection ${c.id}`;
    if (!landmarks.has(c.from) || !landmarks.has(c.to))
      errors.push(`${label} refers to an unknown landmark.`);
    if (c.from === c.to) errors.push(`${label} connects to itself.`);
    if (!['corridor', 'door', 'stairs', 'ramp', 'elevator', 'bridge'].includes(c.type))
      errors.push(`${label} has an unknown type.`);
    if (!['bidirectional', 'one_way'].includes(c.direction))
      errors.push(`${label} has an unknown direction.`);
    if (!['confirmed', 'unsuitable', 'unknown'].includes(c.stepFree))
      errors.push(`${label} has invalid step-free suitability.`);
    if (!['available', 'unavailable', 'unknown'].includes(c.availability))
      errors.push(`${label} has invalid availability.`);
    if (c.lengthMeters != null && (!Number.isFinite(c.lengthMeters) || c.lengthMeters < 0))
      errors.push(`${label} has an invalid length.`);
    if (c.routingCost != null && !positive(c.routingCost))
      errors.push(`${label} has an invalid routing cost.`);
    if (!positive(c.routingCost ?? c.lengthMeters))
      errors.push(`${label} needs a positive routing cost or length.`);
    if (!nonempty(c.instructions?.forward)) errors.push(`${label} needs a forward instruction.`);
    if (c.direction === 'bidirectional' && !nonempty(c.instructions?.reverse))
      errors.push(`${label} needs a reverse instruction.`);
    if (c.type === 'stairs' && c.stepFree === 'confirmed')
      errors.push(`${label} is stairs but claims step-free suitability.`);
    const v = c.verification;
    if (!v || !['simulated', 'unverified', 'verified'].includes(v.status) || !nonempty(v.source)) {
      errors.push(`${label} needs valid verification metadata.`);
    } else {
      if ((map.dataStatus === 'fictional_demo') !== (v.status === 'simulated'))
        errors.push(`${label} mixes simulated and surveyed data.`);
      if (v.status === 'verified' && (!nonempty(v.checkedBy) || !nonempty(v.checkedOn)))
        errors.push(`${label} needs a verifier and date.`);
    }
  }
  return errors;
}

export function withElevatorOutage(map, enabled) {
  return {
    ...map,
    connections: map.connections.map((c) => ({
      ...c,
      availability: enabled && c.type === 'elevator' ? 'unavailable' : c.availability,
    })),
  };
}
