import { escapeHTML as html, typeName, suitabilityName, connectionDetails } from './ui.js';

// Keep the section order and wording alongside the corresponding SwiftUI views.
// These templates do not import Swift: native changes require a deliberate port.
export function demoBanner(map, settings) {
  const outages = settings.simulateElevatorOutage
    ? map.connections
        .filter((c) => c.type === 'elevator')
        .map((c) => `<p>Simulated: ${html(c.name)} is out of service (demo setting).</p>`)
        .join('')
    : '';
  return `<section class="group demo-banner"><h2><span class="warning-icon" aria-hidden="true">⚠</span> Fictional demo data</h2>${outages}</section>`;
}

export function routeSummary(route, map, settings) {
  const banner = demoBanner(map, settings);
  if (!route.ok)
    return `${banner}<section class="group padded"><h2 class="failure-title">No suitable route found</h2><p>${html(route.explanation)}</p></section>${settings.requireStepFree ? '<section class="form-section"><h2 class="section-label">What you can do</h2><div class="group padded"><p>Step-free routes are on, so the app will not substitute a route with stairs or unconfirmed connections.</p><p>Choose a different destination, or ask building staff about other step-free access.</p></div></section>' : ''}`;
  const uses = ['corridor', 'door', 'stairs', 'ramp', 'elevator', 'bridge']
    .map((type) => {
      const count = route.legs.filter((leg) => leg.connection.type === type).length;
      return count ? `${count} ${typeName(type).toLowerCase()}` : null;
    })
    .filter(Boolean)
    .join(', ');
  const length = `${route.recordedLengthMeters} m (simulated)${route.legsWithUnknownLength ? `, plus ${route.legsWithUnknownLength} without a recorded length` : ''}`;
  const rows = [
    ['From', route.start.name],
    ['To', route.destination.name],
    ['Route type', route.requireStepFree ? 'Step-free only' : 'Shortest (may use stairs)'],
    ['Steps to confirm', route.legs.length + 1],
    ['Recorded length', length],
    ['Uses', uses],
  ];
  return `${banner}<section class="form-section"><h2 class="section-label">Summary</h2><div class="group"><dl class="labeled-list">${rows.map(([label, value]) => `<div><dt>${label}</dt><dd>${html(value)}</dd></div>`).join('')}</dl></div></section>
    ${route.warnings.length ? `<section class="form-section"><h2 class="section-label">Before you go</h2><ul class="group warning-list">${route.warnings.map((warning) => `<li>${html(warning)}</li>`).join('')}</ul></section>` : ''}
    <div class="summary-action"><button id="start-guidance" class="button primary full">Start guidance</button></div>
    <section class="form-section"><h2 class="section-label">Steps</h2><ol class="group route-steps">${route.legs.map((leg, index) => `<li><p>${index + 1}. ${html(leg.instruction)}</p><p class="arrival">Arrive at: ${html(leg.to.name)}</p><p class="secondary">${html(typeName(leg.connection.type))} · ${html(suitabilityName(leg.connection.stepFree))}</p></li>`).join('')}</ol></section>
    <section class="form-section"><h2 class="section-label">Schematic (not to scale)</h2><div id="map" class="group floor-maps"></div><p class="section-footer">A simplified drawing. The steps above contain all the route information.</p></section>`;
}

export function guidanceContent(steps, index, settings, speechSupported, speechPaused) {
  const step = steps[index];
  const preview = (title, item) =>
    item
      ? `<section class="preview-card"><h2>${title}</h2><p>${html(item.instruction)}</p></section>`
      : '';
  return `<p class="guidance-notice"><span class="warning-icon" aria-hidden="true">⚠</span> Fictional demo route</p>
    <div><h2 id="guidance-instruction" class="guidance-instruction" tabindex="-1" aria-label="${html(`Step ${index + 1} of ${steps.length}. ${step.instruction}${step.cue ? ` Arrival cue: ${step.cue}` : ''}`)}">${html(step.instruction)}</h2>
    ${step.cue ? `<p class="guidance-cue" aria-hidden="true">Arrival cue: ${html(step.cue)}</p>` : ''}
    ${step.connection ? `<p class="guidance-details secondary">${html(connectionDetails(step.connection))}</p>` : ''}</div>
    <button id="${step.confirm ? 'confirm-step' : 'finish-guidance'}" class="button primary guidance-confirm">${html(step.confirm ?? 'Finish')}</button>
    <div class="secondary-controls"><button id="previous-step" class="button" ${index === 0 ? 'disabled' : ''}>Previous step</button>
    ${settings.spokenDirections ? `<button id="repeat-step" class="button" ${speechSupported ? '' : 'disabled'}>Repeat</button><button id="pause-speech" class="button" ${speechSupported ? '' : 'disabled'}>${speechPaused ? 'Resume speech' : 'Pause speech'}</button>` : ''}</div>
    <div>${preview('Next', steps[index + 1])}${preview('Previous', steps[index - 1])}${settings.spokenDirections ? '' : '<p class="secondary guidance-note">Spoken directions are off. Turn them on in Settings.</p>'}</div>`;
}
