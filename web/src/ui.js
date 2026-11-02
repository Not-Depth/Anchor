export const escapeHTML = (value) =>
  String(value).replace(
    /[&<>"']/g,
    (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char],
  );
export const typeName = (type) =>
  ({
    corridor: 'Corridor',
    door: 'Door',
    stairs: 'Stairs',
    ramp: 'Ramp',
    elevator: 'Elevator',
    bridge: 'Bridge',
  })[type];
export const suitabilityName = (value) =>
  ({
    confirmed: 'Step-free: confirmed',
    unsuitable: 'Step-free: not suitable',
    unknown: 'Step-free: unknown',
  })[value];
export function connectionDetails(c) {
  return `${typeName(c.type)}: ${c.name}\n${c.lengthMeters == null ? 'Length not recorded' : `Recorded length: ${c.lengthMeters} m (simulated)`}\n${suitabilityName(c.stepFree)}\n${c.availability === 'unknown' ? 'Availability unknown' : c.availability === 'unavailable' ? 'Unavailable' : 'Available'}`;
}

// Follow RouteSchematicView.swift: visited floors, numbered stops, dashed route,
// and an equivalent text itinerary. This is still a separate browser renderer.
export function renderMap(container, map, route) {
  const used = new Set(route.legs.map((leg) => leg.connection.id));
  const landmarks = new Map(map.landmarks.map((landmark) => [landmark.id, landmark]));
  const visited = [route.start, ...route.legs.map((leg) => leg.to)];
  const floorIDs = [...new Set(visited.map((landmark) => landmark.floorID))];
  const point = (landmark) => ({
    x: 24 + landmark.schematic.x * 352,
    y: 24 + landmark.schematic.y * 172,
  });
  container.innerHTML =
    floorIDs
      .map((floorID) => {
        const floor = map.floors.find((f) => f.id === floorID);
        const lines = map.connections
          .map((c) => {
            const a = landmarks.get(c.from),
              b = landmarks.get(c.to);
            if (a.floorID !== floorID || b.floorID !== floorID || !a.schematic || !b.schematic)
              return null;
            const start = point(a),
              end = point(b);
            return {
              active: used.has(c.id),
              markup: `<path d="M${start.x},${start.y} L${end.x},${end.y}" class="map-path ${used.has(c.id) ? 'active' : ''}"/>`,
            };
          })
          .filter(Boolean)
          .sort((a, b) => Number(a.active) - Number(b.active))
          .map((line) => line.markup)
          .join('');
        const dots = map.landmarks
          .filter((l) => l.floorID === floorID && l.schematic)
          .map((landmark) => {
            const p = point(landmark),
              order = visited.findIndex((l) => l.id === landmark.id);
            return `<circle cx="${p.x}" cy="${p.y}" r="${order < 0 ? 4 : 11}" class="map-node ${order < 0 ? '' : 'active'}"/>${order < 0 ? '' : `<text x="${p.x}" y="${p.y}" class="map-number">${order + 1}</text>`}`;
          })
          .join('');
        return `<div class="floor"><h3>${escapeHTML(floor.name)}</h3><svg aria-hidden="true" viewBox="0 0 400 220" focusable="false">${lines}${dots}</svg><p class="sr-only">Route passes ${escapeHTML(
          visited
            .filter((l) => l.floorID === floorID)
            .map((l) => l.name)
            .join(', then '),
        )}.</p></div>`;
      })
      .join('') +
    '<p class="map-legend">Numbered circles are the route’s landmarks in order. Dashed line: route. Thin line: other connections. Floor changes are not drawn.</p>';
}
