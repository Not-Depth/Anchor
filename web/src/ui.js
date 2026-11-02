export const escapeHTML = (value) =>
  String(value).replace(
    /[&<>"']/g,
    (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char],
  );

export function connectionDetails(c) {
  const suitability = {
    confirmed: 'Step-free: confirmed',
    unsuitable: 'Not suitable for step-free travel',
    unknown: 'Step-free suitability unknown',
  };
  return `${c.type} · ${c.lengthMeters == null ? 'Length not recorded' : `${c.lengthMeters} m recorded (simulated)`} · ${suitability[c.stepFree]} · ${c.availability === 'unknown' ? 'Availability unknown' : c.availability}`;
}

export function renderMap(container, map, route, currentID) {
  const used = new Set(route?.ok ? route.legs.map((leg) => leg.connection.id) : []);
  const landmarks = new Map(map.landmarks.map((landmark) => [landmark.id, landmark]));
  const visited = new Set(route?.ok ? [route.start.id, ...route.legs.map((leg) => leg.to.id)] : []);
  const point = (landmark) => ({
    x: 32 + landmark.schematic.x * 280,
    y: 36 + landmark.schematic.y * 250,
  });
  container.innerHTML = [...map.floors]
    .sort((a, b) => a.level - b.level)
    .map((floor, floorID) => {
      const nodes = map.landmarks.filter(
        (landmark) => landmark.floorID === floor.id && landmark.schematic,
      );
      const lines = map.connections
        .flatMap((c) => {
          const a = landmarks.get(c.from),
            b = landmarks.get(c.to);
          if (a.floorID !== floor.id || b.floorID !== floor.id || !a.schematic || !b.schematic)
            return [];
          const start = point(a),
            end = point(b);
          // Parallel ramp/stair connections get a small offset so neither hides the other.
          const offset = c.type === 'ramp' ? 9 : 0;
          return [
            {
              active: used.has(c.id),
              markup: `<path d="M${start.x + offset},${start.y} L${end.x + offset},${end.y}" class="map-path ${used.has(c.id) ? 'active' : ''} ${c.availability === 'unavailable' ? 'unavailable' : ''}" ${c.direction === 'one_way' ? `marker-end="url(#arrow-${floorID})"` : ''}/>`,
            },
          ];
        })
        .sort((a, b) => Number(a.active) - Number(b.active))
        .map((line) => line.markup)
        .join('');
      const dots = nodes
        .map((landmark) => {
          const p = point(landmark);
          const label = landmark.name
            .replace(/ \(.*\)/, '')
            .replace(', Floor 1', '')
            .replace(', Floor 2', '')
            .replace('Stairwell A door', 'Stairs A')
            .replace('Elevator A lobby', 'Elevator A')
            .replace('Main Entrance lobby', 'Entrance')
            .replace('Annex reading room', 'Annex');
          const alignment = landmark.schematic.x > 0.8 ? 'end' : 'start';
          return `<g><circle cx="${p.x}" cy="${p.y}" r="${landmark.id === currentID ? 9 : 6}" class="map-node ${visited.has(landmark.id) ? 'active' : ''}"/><text x="${p.x + (alignment === 'end' ? -10 : 10)}" y="${p.y - 12}" text-anchor="${alignment}">${escapeHTML(label)}</text></g>`;
        })
        .join('');
      return `<div class="floor"><div class="floor-title"><strong>${escapeHTML(floor.name)}</strong><span>${nodes.length} landmarks</span></div><svg viewBox="0 0 350 310" focusable="false"><defs><pattern id="grid-${floorID}" width="20" height="20" patternUnits="userSpaceOnUse"><circle cx="1" cy="1" r="0.8" fill="#d8e1d9"/></pattern><marker id="arrow-${floorID}" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="4" markerHeight="4" orient="auto-start-reverse"><path d="M0 0L10 5L0 10" fill="#758c81"/></marker></defs><rect width="350" height="310" fill="url(#grid-${floorID})"/>${lines}${dots}</svg></div>`;
    })
    .join('');
}
