import { validateMap, withElevatorOutage } from './core/map.js';
import { planRoute } from './core/routing.js';
import { guidanceSteps, moveStep } from './core/guidance.js';
import { loadSettings, saveSettings } from './core/settings.js';
import { ProximityPolicy } from './core/proximity.js';
import { escapeHTML as html, renderMap, connectionDetails } from './ui.js';

const $ = (selector) => document.querySelector(selector);
const all = (selector) => document.querySelectorAll(selector);
let storage;
try {
  storage = window.localStorage;
} catch {
  /* Storage is optional. */
}
const settings = loadSettings(storage);
const state = {
  map: null,
  route: null,
  steps: null,
  step: 0,
  tab: 'routes',
  simulation: null,
  policy: null,
};
const speechSupported = 'speechSynthesis' in window && 'SpeechSynthesisUtterance' in window;
const vibrationSupported = typeof navigator.vibrate === 'function';

function stopSpeech() {
  if (speechSupported) window.speechSynthesis.cancel();
}
function speak(text) {
  if (!speechSupported) return;
  stopSpeech();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = 'en-US';
  window.speechSynthesis.speak(utterance);
}

function currentMap() {
  return withElevatorOutage(state.map, settings.simulateElevatorOutage);
}
function updateMap() {
  renderMap($('#map'), currentMap(), state.route, state.steps?.[state.step]?.landmarkID);
}
function focusResult() {
  $('#result-heading')?.focus();
}

function renderRoute() {
  const route = state.route;
  updateMap();
  if (!route) {
    $('#result').innerHTML =
      '<div class="empty-state"><span class="empty-icon" aria-hidden="true">↗</span><div><h2>Your next step starts here</h2><p>Pick two places to see your route and landmark-by-landmark directions.</p></div></div>';
    return;
  }
  if (!route.ok) {
    $('#result').innerHTML =
      `<p class="eyebrow">LET’S CHECK THAT ROUTE</p><h2 id="result-heading" tabindex="-1">${route.reason === 'same_location' || route.reason === 'unknown_landmark' ? 'Check your locations' : 'No suitable route found'}</h2><p class="warning">${html(route.explanation)}</p><p class="muted">Your preferences are kept as selected. Review the places or demo conditions to try another route.</p>`;
    return;
  }
  const routeKind = route.requireStepFree
    ? 'Step-free route'
    : route.usesStairs
      ? 'Includes stairs'
      : 'Route found';
  $('#result').innerHTML =
    `<span class="pill ${route.usesStairs ? 'amber' : 'neutral'}">${routeKind}</span><h2 id="result-heading" tabindex="-1" class="result-title">${html(route.start.name)} → ${html(route.destination.name)}</h2><p class="route-summary">Follow the authored landmarks and confirm each arrival. All route data is fictional.</p><div class="metrics"><div><strong>${route.legs.length} connections</strong><span>One at a time</span></div><div><strong>${route.recordedLengthMeters} m recorded</strong><span>Simulated lengths only</span></div><div><strong>${route.legsWithUnknownLength} unrecorded</strong><span>Connections without a length</span></div></div>${route.warnings.length ? `<div class="warning"><strong>Before you go</strong><ul>${route.warnings.map((warning) => `<li>${html(warning)}</li>`).join('')}</ul></div>` : ''}<button id="start-guidance" class="button primary">Start guidance <span aria-hidden="true">→</span></button><details><summary class="details-toggle">Review all route steps</summary><ol class="steps">${route.legs.map((leg) => `<li><h3>${html(leg.to.name)}</h3><p>${html(leg.instruction)}</p><p class="arrival-cue">Arrival cue: ${html(leg.to.arrivalCue)}</p><small>${html(connectionDetails(leg.connection))}</small></li>`).join('')}</ol></details>`;
}

function renderGuidance(announce = true) {
  const step = state.steps[state.step];
  const finished = !step.confirm;
  updateMap();
  $('#result').innerHTML =
    `<p class="eyebrow">${finished ? 'DESTINATION CONFIRMED' : 'ONE LANDMARK AT A TIME'}</p><h2 id="result-heading" tabindex="-1">${finished ? 'You’ve arrived.' : `Step ${state.step + 1} of ${state.steps.length}`}</h2><progress class="progress-track" value="${state.step}" max="${state.steps.length - 1}" aria-label="Guidance progress"></progress><p id="guidance-instruction" class="guidance-instruction">${html(step.instruction)}</p>${step.cue ? `<div class="guidance-cue"><strong>What to look or listen for</strong><p>${html(step.cue)}</p></div>` : ''}${step.connection ? `<p class="muted">${html(connectionDetails(step.connection))}</p>` : ''}<p class="muted">Fictional demo · Your location is not tracked. Confirm only when you reach the landmark.</p><div class="actions">${step.confirm ? `<button id="confirm-step" class="button primary guidance-confirm">${html(step.confirm)}</button>` : '<button id="finish-guidance" class="button primary">Back to route overview</button>'}<button id="previous-step" class="button" ${state.step === 0 ? 'disabled' : ''}>Previous step</button><button id="repeat-step" class="button" ${speechSupported ? '' : 'disabled'}>Read aloud</button>${!finished ? '<button id="end-guidance" class="button">End guidance</button>' : ''}</div>`;
  if (announce) {
    // Browsers cannot detect screen-reader use. Speech is opt-in and the current
    // text receives focus, so assistive technology can read the same instruction.
    $('#guidance-instruction').tabIndex = -1;
    $('#guidance-instruction').focus();
    if (settings.spokenDirections)
      speak(step.instruction + (step.cue ? ` Arrival cue: ${step.cue}` : ''));
  }
}

function findRoute() {
  stopSpeech();
  state.steps = null;
  state.step = 0;
  state.route = planRoute(
    currentMap(),
    $('#start').value,
    $('#destination').value,
    settings.requireStepFree,
  );
  $('#route-notice').textContent = settings.simulateElevatorOutage
    ? 'Demo condition: elevators are unavailable.'
    : '';
  renderRoute();
  focusResult();
}

function syncSettings() {
  all('[data-setting]').forEach((input) => {
    if (input.type === 'checkbox') input.checked = settings[input.dataset.setting];
    else input.value = settings[input.dataset.setting];
  });
  $('#threshold-label').textContent = `${settings.nearbyAlertDistance} m`;
}

function persistSettings() {
  $('#settings-status').textContent = saveSettings(storage, settings)
    ? 'Preferences saved in this browser.'
    : 'Storage is unavailable. Your preferences will last for this session only.';
}

function changeSetting(key, value) {
  settings[key] = value;
  syncSettings();
  persistSettings();
  if (key === 'requireStepFree' || key === 'simulateElevatorOutage') {
    stopSpeech();
    state.steps = null;
    state.route = null;
    renderRoute();
    $('#route-notice').textContent =
      `Routing preferences changed. Find a new route.${settings.simulateElevatorOutage ? ' Demo elevators are unavailable.' : ''}`;
  }
  if (key === 'spokenDirections' || key === 'nearbyAudioAlerts') stopSpeech();
  if (key === 'nearbyAlertDistance') state.policy = new ProximityPolicy(value);
}

function updateDistance() {
  const unreliable = $('#unreliable').checked;
  const distance = Number($('#distance').value);
  $('#distance-value').textContent = `${distance.toFixed(2)} m`;
  $('#distance-reading').textContent = unreliable ? '—' : distance.toFixed(2);
  $('#distance-unit').textContent = unreliable ? '' : 'm';
  $('#sensor-state').textContent = !state.simulation
    ? 'Simulation stopped'
    : unreliable
      ? 'No reliable simulated reading'
      : distance <= settings.nearbyAlertDistance
        ? 'Inside the alert distance (simulated)'
        : 'Outside the alert distance (simulated)';
}

function simulationTick() {
  updateDistance();
  const distance = $('#unreliable').checked ? null : Number($('#distance').value);
  const event = state.policy.update(distance, performance.now());
  if (!event) return;
  const message =
    event === 'near'
      ? `Simulated surface within ${distance.toFixed(2)} meters.`
      : event === 'unreliable'
        ? 'Simulated depth readings unavailable.'
        : 'Simulated depth readings restored.';
  $('#nearby-event').textContent = message;
  if (settings.nearbyAudioAlerts) speak(message);
  if (settings.nearbyHapticAlerts && vibrationSupported && event !== 'restored')
    navigator.vibrate([120, 80, 120]);
}

function stopSimulation(message = 'Simulation stopped.') {
  if (!state.simulation) return;
  clearInterval(state.simulation);
  state.simulation = null;
  stopSpeech();
  if (vibrationSupported) navigator.vibrate(0);
  $('#simulation-toggle').textContent = 'Start simulation';
  $('#nearby-event').textContent = message;
  updateDistance();
}

function switchTab(focus = true) {
  const requested = window.location.hash.slice(1);
  const tab = ['routes', 'nearby', 'settings'].includes(requested) ? requested : 'routes';
  if (tab !== 'nearby') stopSimulation('Simulation stopped when you left Nearby.');
  stopSpeech();
  state.tab = tab;
  for (const name of ['routes', 'nearby', 'settings']) $(`#${name}-view`).hidden = name !== tab;
  all('nav a').forEach((link) => {
    if (link.hash === `#${tab}`) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  });
  if (focus && state.map) $(`#${tab}-heading`).focus();
}

$('#route-form').addEventListener('submit', (event) => {
  event.preventDefault();
  findRoute();
});
for (const input of [$('#start'), $('#destination')])
  input.addEventListener('change', () => {
    stopSpeech();
    state.steps = null;
    state.route = null;
    renderRoute();
    $('#route-notice').textContent = 'Locations changed. Find a new route.';
  });
all('[data-setting]').forEach((input) =>
  input.addEventListener('change', () =>
    changeSetting(
      input.dataset.setting,
      input.type === 'checkbox' ? input.checked : Number(input.value),
    ),
  ),
);
all('[data-scenario]').forEach((button) =>
  button.addEventListener('click', () => {
    settings.requireStepFree = true;
    settings.simulateElevatorOutage = button.dataset.scenario === 'outage';
    syncSettings();
    persistSettings();
    $('#start').value = 'plaza';
    $('#destination').value = 'room-201';
    findRoute();
  }),
);
$('#result').addEventListener('click', (event) => {
  const id = event.target.closest('button')?.id;
  if (id === 'start-guidance') {
    state.steps = guidanceSteps(state.route);
    state.step = 0;
    renderGuidance();
  } else if (id === 'confirm-step' || id === 'previous-step') {
    stopSpeech();
    state.step = moveStep(state.step, id === 'confirm-step' ? 1 : -1, state.steps);
    renderGuidance();
  } else if (id === 'repeat-step') {
    const step = state.steps[state.step];
    speak(step.instruction + (step.cue ? ` Arrival cue: ${step.cue}` : ''));
  } else if (id === 'end-guidance' || id === 'finish-guidance') {
    stopSpeech();
    state.steps = null;
    renderRoute();
    focusResult();
  }
});
$('#simulation-toggle').addEventListener('click', () => {
  if (state.simulation) stopSimulation();
  else {
    state.policy = new ProximityPolicy(settings.nearbyAlertDistance);
    state.simulation = setInterval(simulationTick, 200);
    $('#simulation-toggle').textContent = 'Stop simulation';
    $('#nearby-event').textContent = 'Simulation running. Move the slider to test alerts.';
    simulationTick();
  }
});
$('#distance').addEventListener('input', updateDistance);
$('#unreliable').addEventListener('change', updateDistance);
$('.skip-link').addEventListener('click', (event) => {
  // Keep the skip target out of the hash router, which would move focus again.
  event.preventDefault();
  $('#main').focus();
});
window.addEventListener('hashchange', () => switchTab());
document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    stopSimulation('Simulation paused while this tab was hidden. Start it again to continue.');
    stopSpeech();
  }
});
window.addEventListener('pagehide', () => {
  stopSimulation();
  stopSpeech();
});
$('#retry').addEventListener('click', () => loadMap());

$('#speech-support').textContent = speechSupported
  ? 'Browser speech is available. Voice availability varies by device.'
  : 'Speech is unavailable in this browser. All directions remain visible as text.';
$('#vibration-support').textContent = vibrationSupported
  ? 'This browser exposes vibration. Your hardware may still ignore it.'
  : 'Vibration is unavailable in this browser. Visual and optional audio alerts still work.';
all('[data-setting="spokenDirections"], [data-setting="nearbyAudioAlerts"]').forEach((input) => {
  input.disabled = !speechSupported;
});
$('[data-setting="nearbyHapticAlerts"]').disabled = !vibrationSupported;
syncSettings();
switchTab(false);

async function loadMap() {
  $('#loading').hidden = false;
  $('#load-error').hidden = true;
  try {
    const response = await fetch('./data/demo_map.json', { cache: 'no-cache' });
    if (!response.ok) throw new Error(`Map request failed (${response.status}).`);
    const map = await response.json();
    const errors = validateMap(map);
    if (errors.length) throw new Error(errors.join(' '));
    state.map = map;
    $('#disclaimer').textContent = map.disclaimer;
    for (const [selector, key] of [
      ['#start', 'canStartHere'],
      ['#destination', 'isDestination'],
    ]) {
      $(selector).replaceChildren(
        ...map.landmarks
          .filter((landmark) => landmark[key])
          .map((landmark) => new Option(landmark.name, landmark.id)),
      );
    }
    $('#start').value = 'plaza';
    $('#destination').value = 'room-201';
    $('#app').hidden = false;
    if (settings.simulateElevatorOutage)
      $('#route-notice').textContent = 'Demo condition: elevators are unavailable.';
    updateMap();
  } catch (error) {
    $('#app').hidden = true;
    $('#load-error').hidden = false;
    $('#load-error-message').textContent =
      `Start the app with npm start and check the map data. ${error.message}`;
  } finally {
    $('#loading').hidden = true;
  }
}
loadMap();
