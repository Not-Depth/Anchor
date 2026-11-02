export const isStepFree = (connection) =>
  connection.type !== 'stairs' && connection.stepFree === 'confirmed';

export function planRoute(map, startID, destinationID, requireStepFree = false) {
  const byID = new Map(map.landmarks.map((landmark) => [landmark.id, landmark]));
  if (!byID.has(startID) || !byID.has(destinationID))
    return {
      ok: false,
      reason: 'unknown_landmark',
      explanation: 'Choose a starting point and destination from this map.',
    };
  if (startID === destinationID)
    return {
      ok: false,
      reason: 'same_location',
      explanation: 'Choose a destination different from your starting point.',
    };
  const outgoing = new Map(map.landmarks.map((landmark) => [landmark.id, []]));
  for (const connection of map.connections) {
    outgoing
      .get(connection.from)
      .push({ connection, from: connection.from, to: connection.to, reversed: false });
    if (connection.direction === 'bidirectional')
      outgoing
        .get(connection.to)
        .push({ connection, from: connection.to, to: connection.from, reversed: true });
  }

  // Diagnostic searches minimize blocked connections first, then routing cost.
  // They explain a failure only: their paths must never become offered routes.
  function search(availabilityRule, suitabilityRule) {
    const costs = new Map([[startID, [0, 0]]]);
    const previous = new Map();
    const frontier = new Set([startID]);
    const settled = new Set();
    const compare = (a, b) => a[0] - b[0] || a[1] - b[1];
    while (frontier.size) {
      const current = [...frontier].sort(
        (a, b) => compare(costs.get(a), costs.get(b)) || (a < b ? -1 : a > b ? 1 : 0),
      )[0];
      frontier.delete(current);
      if (current === destinationID) break;
      settled.add(current);
      for (const edge of outgoing.get(current)) {
        if (settled.has(edge.to)) continue;
        let blocked = 0;
        let excluded = false;
        for (const [violated, rule] of [
          [edge.connection.availability === 'unavailable', availabilityRule],
          [!isStepFree(edge.connection), suitabilityRule],
        ]) {
          if (!violated) continue;
          if (rule === 'exclude') excluded = true;
          if (rule === 'penalize') blocked += 1;
        }
        if (excluded) continue;
        const prior = costs.get(current);
        const candidate = [
          prior[0] + blocked,
          prior[1] + (edge.connection.routingCost ?? edge.connection.lengthMeters),
        ];
        if (!costs.has(edge.to) || compare(candidate, costs.get(edge.to)) < 0) {
          costs.set(edge.to, candidate);
          previous.set(edge.to, edge);
          frontier.add(edge.to);
        }
      }
    }
    if (!costs.has(destinationID)) return null;
    const edges = [];
    for (let node = destinationID; previous.has(node);) {
      const edge = previous.get(node);
      edges.push(edge);
      node = edge.from;
    }
    return { edges: edges.reverse(), cost: costs.get(destinationID)[1] };
  }

  const suitability = requireStepFree ? 'exclude' : 'allow';
  const path = search('exclude', suitability);
  if (!path) {
    const attempts = [
      ['unavailable', 'penalize', suitability, (c) => c.availability === 'unavailable'],
      ...(requireStepFree
        ? [
            ['step_free', 'exclude', 'penalize', (c) => !isStepFree(c)],
            [
              'both',
              'penalize',
              'penalize',
              (c) => c.availability === 'unavailable' || !isStepFree(c),
            ],
          ]
        : []),
    ];
    for (const [reason, availabilityRule, suitabilityRule, isBlocker] of attempts) {
      const relaxed = search(availabilityRule, suitabilityRule);
      if (!relaxed) continue;
      const blockers = [
        ...new Map(
          relaxed.edges
            .map((e) => e.connection)
            .filter(isBlocker)
            .map((c) => [c.id, c]),
        ).values(),
      ];
      return {
        ok: false,
        reason,
        blockers,
        explanation: `No route meets your preferences. Blocking connections: ${blockers.map(describeBlocker).join('; ')}.`,
      };
    }
    return {
      ok: false,
      reason: 'not_connected',
      blockers: [],
      explanation: 'These places are not connected in this map.',
    };
  }
  const legs = path.edges.map((edge, index) => ({
    ...edge,
    index,
    from: byID.get(edge.from),
    to: byID.get(edge.to),
    instruction: edge.connection.instructions[edge.reversed ? 'reverse' : 'forward'],
  }));
  const warnings = legs.flatMap(({ connection: c }) => [
    ...(c.availability === 'unknown' ? [`${c.name}: current availability is not confirmed.`] : []),
    ...(c.verification.status === 'unverified'
      ? [`${c.name}: details have not been verified on site.`]
      : []),
    ...(!requireStepFree && c.stepFree === 'unknown'
      ? [`${c.name}: step-free suitability is unknown.`]
      : []),
  ]);
  return {
    ok: true,
    start: byID.get(startID),
    destination: byID.get(destinationID),
    legs,
    warnings,
    totalRoutingCost: path.cost,
    requireStepFree,
    recordedLengthMeters: legs.reduce((sum, leg) => sum + (leg.connection.lengthMeters ?? 0), 0),
    legsWithUnknownLength: legs.filter((leg) => leg.connection.lengthMeters == null).length,
    usesStairs: legs.some((leg) => leg.connection.type === 'stairs'),
  };
}

function describeBlocker(c) {
  const reasons = [];
  if (c.availability === 'unavailable') reasons.push('unavailable');
  if (c.type === 'stairs') reasons.push('stairs');
  else if (c.stepFree === 'unknown') reasons.push('step-free suitability unknown');
  else if (c.stepFree === 'unsuitable') reasons.push('not suitable for step-free travel');
  return `${c.name} (${reasons.join(', ')})`;
}
