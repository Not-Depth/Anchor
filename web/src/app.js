import { validateMap, withElevatorOutage } from './core/map.js';
import { planRoute } from './core/routing.js';
import { guidanceSteps, moveStep } from './core/guidance.js';
import { loadSettings, saveSettings } from './core/settings.js';
import { ProximityPolicy } from './core/proximity.js';
import { escapeHTML as html, renderMap } from './ui.js';
import { routeSummary, guidanceContent } from './views.js';

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
  startID: '',
  destinationID: '',
  route: null,
  steps: null,
  step: 0,
  screen: 'routes',
  speechPaused: false,
  simulation: null,
  policy: null,
};
const speechSupported = 'speechSynthesis' in window && 'SpeechSynthesisUtterance' in window;
const vibrationSupported = typeof navigator.vibrate === 'function';
const dialog = $('#end-route-dialog');

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
function speakStep() {
  const step = state.steps[state.step];
  speak(step.instruction + (step.cue ? ` Arrival cue: ${step.cue}` : ''));
}
function currentMap() {
  return withElevatorOutage(state.map, settings.simulateElevatorOutage);
}
function canSearch() {
  return Boolean(state.startID && state.destinationID && state.startID !== state.destinationID);
}

function updateSelections() {
  for (const [key, title] of [
    ['start', 'Starting point'],
    ['destination', 'Destination'],
  ]) {
    const name =
      state.map.landmarks.find((landmark) => landmark.id === state[`${key}ID`])?.name ??
      'Not selected';
    $(`#${key}-value`).textContent = name;
    $(`#${key}-picker`).setAttribute('aria-label', `${title}, ${name}`);
  }
  $('#find-route').disabled = !canSearch();
  $('#search-hint').textContent =
    !state.startID || !state.destinationID
      ? 'Choose a starting point and destination first.'
      : state.startID === state.destinationID
        ? 'Starting point and destination are the same.'
        : 'Shows a summary of the route before guidance starts.';
}

function renderPicker(kind) {
  const key = kind === 'start' ? 'canStartHere' : 'isDestination';
  $('#picker-heading').textContent = kind === 'start' ? 'Starting point' : 'Destination';
  const option = (id, name) =>
    `<label class="option-row"><span>${html(name)}</span><input type="radio" name="landmark" value="${html(id)}" ${state[`${kind}ID`] === id ? 'checked' : ''}></label>`;
  $('#picker-options').innerHTML =
    `<div class="group">${option('', 'Not selected')}</div>` +
    [...state.map.floors]
      .sort((a, b) => a.level - b.level)
      .map((floor) => {
        const choices = state.map.landmarks.filter(
          (landmark) => landmark.floorID === floor.id && landmark[key],
        );
        return choices.length
          ? `<section class="form-section"><h2 class="section-label">${html(floor.name)}</h2><div class="group">${choices.map((landmark) => option(landmark.id, landmark.name)).join('')}</div></section>`
          : '';
      })
      .join('');
  $('#picker-options').setAttribute('role', 'radiogroup');
  $('#picker-options').setAttribute('aria-labelledby', 'picker-heading');
}

function renderRoute() {
  state.route = planRoute(
    currentMap(),
    state.startID,
    state.destinationID,
    settings.requireStepFree,
  );
  $('#result').innerHTML = routeSummary(state.route, state.map, settings);
  if (state.route.ok) renderMap($('#map'), currentMap(), state.route);
}

function renderGuidance(announce = true) {
  $('#guidance-heading').textContent = `Step ${state.step + 1} of ${state.steps.length}`;
  $('#guidance-content').innerHTML = guidanceContent(
    state.steps,
    state.step,
    settings,
    speechSupported,
    state.speechPaused,
  );
  if (announce) {
    // Browser speech remains opt-in: unlike SwiftUI, browsers cannot detect VoiceOver.
    // The focused instruction includes progress and the arrival cue for screen readers.
    $('#guidance-instruction').focus();
    if (settings.spokenDirections && !state.speechPaused) speakStep();
  }
}

function goTo(screen, { replace = false, focusID } = {}) {
  if (window.location.hash !== `#${screen}`)
    history[replace ? 'replaceState' : 'pushState'](null, '', `#${screen}`);
  showScreen(true, focusID);
}

function showScreen(focus = true, focusID) {
  if (!state.map) return;
  let screen = window.location.hash.slice(1) || 'routes';
  if (
    ![
      'routes',
      'route',
      'guidance',
      'pick-start',
      'pick-destination',
      'nearby',
      'settings',
    ].includes(screen) ||
    (screen === 'route' && !canSearch()) ||
    (screen === 'guidance' && !state.steps)
  ) {
    screen = 'routes';
    history.replaceState(null, '', '#routes');
  }
  stopSpeech();
  if (screen !== 'nearby') stopSimulation('Simulation stopped when you left Nearby.');
  if (screen !== 'guidance' && state.steps) state.steps = null;
  if (dialog.open) dialog.close();
  state.screen = screen;
  const view = screen.startsWith('pick-') ? 'picker' : screen;
  for (const name of ['routes', 'picker', 'route', 'guidance', 'nearby', 'settings'])
    $(`#${name}-view`).hidden = name !== view;
  $('#tab-bar').hidden = screen === 'guidance';
  $('.app-shell').classList.toggle('guidance-mode', screen === 'guidance');
  $('.app-shell').classList.toggle('plain-mode', screen === 'guidance' || screen === 'nearby');
  const tab = ['settings', 'nearby'].includes(screen) ? screen : 'routes';
  all('[data-tab]').forEach((link) => {
    if (link.dataset.tab === tab) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  });
  if (screen === 'routes') {
    state.route = null;
    updateSelections();
  }
  if (screen.startsWith('pick-')) renderPicker(screen.slice(5));
  if (screen === 'route') renderRoute();
  // Preserve the Routes navigation stack when visiting another tab, as TabView does.
  $('[data-tab="routes"]').href = state.route ? '#route' : '#routes';
  window.scrollTo(0, 0);
  if (screen === 'guidance') {
    renderGuidance();
    return;
  }
  const heading = screen === 'route' ? 'result-heading' : `${view}-heading`;
  if (focus) document.getElementById(focusID ?? heading)?.focus({ preventScroll: true });
}

function syncSettings() {
  all('[data-setting]').forEach((input) => {
    if (input.type === 'checkbox') input.checked = settings[input.dataset.setting];
    else input.value = settings[input.dataset.setting];
  });
  $('#step-free-description').textContent = settings.requireStepFree
    ? 'Only connections confirmed step-free are used. Stairs and anything unconfirmed are excluded.'
    : 'The shortest route may include stairs.';
  $('#threshold-label').textContent = `${settings.nearbyAlertDistance} m`;
  const alerts = [
    settings.nearbyAudioAlerts && 'audio',
    settings.nearbyHapticAlerts && 'haptic',
  ].filter(Boolean);
  $('#alert-summary').textContent = alerts.length
    ? `Simulated alerts on (${alerts.join(' and ')}) for surfaces closer than ${settings.nearbyAlertDistance} m. Change in Settings.`
    : 'Alerts are off. Turn on audio or haptic alerts in Settings.';
  const outages =
    settings.simulateElevatorOutage && state.map
      ? state.map.connections
          .filter((c) => c.type === 'elevator')
          .map((c) => `Simulated: ${c.name} is out of service (demo setting).`)
          .join(' ')
      : '';
  $('.outage-notice').hidden = !outages;
  $('.outage-notice').textContent = outages;
}

function changeSetting(key, value) {
  settings[key] = value;
  syncSettings();
  $('#settings-status').textContent = saveSettings(storage, settings)
    ? 'Preferences saved in this browser.'
    : 'Storage is unavailable. Your preferences will last for this session only.';
  if (key === 'requireStepFree' || key === 'simulateElevatorOutage') {
    stopSpeech();
    state.steps = null;
    if (state.route) renderRoute();
    $('#route-notice').textContent = 'Routing preferences updated.';
  }
  if (key === 'spokenDirections' || key === 'nearbyAudioAlerts') stopSpeech();
  if (key === 'nearbyAlertDistance') state.policy = new ProximityPolicy(value);
}

function updateDistance() {
  const unreliable = $('#unreliable').checked;
  const distance = Number($('#distance').value);
  const hasReading = state.simulation && !unreliable;
  $('#distance-value').textContent = `${distance.toFixed(2)} m`;
  $('#distance-reading').textContent = hasReading ? distance.toFixed(2) : '—';
  $('#distance-unit').textContent = hasReading ? 'm' : '';
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
function finishGuidance() {
  stopSpeech();
  state.steps = null;
  if (dialog.open) dialog.close();
  goTo('route', { replace: true });
}

$('#route-form').addEventListener('submit', (event) => {
  event.preventDefault();
  if (canSearch()) goTo('route');
});
for (const kind of ['start', 'destination'])
  $(`#${kind}-picker`).addEventListener('click', () => goTo(`pick-${kind}`));
all('[data-go]').forEach((button) =>
  button.addEventListener('click', () => goTo(button.dataset.go)),
);
$('#picker-options').addEventListener('change', (event) => {
  if (!state.screen.startsWith('pick-') || !event.target.matches('input[name="landmark"]')) return;
  const kind = state.screen.slice(5);
  state[`${kind}ID`] = event.target.value;
  state.route = null;
  state.steps = null;
  $('#route-notice').textContent = '';
  goTo('routes', { focusID: `${kind}-picker` });
});
$('#picker-options').addEventListener('click', (event) => {
  if (!state.screen.startsWith('pick-') || !event.target.matches('input[name="landmark"]')) return;
  const kind = state.screen.slice(5);
  // A radio's change event does not fire when the existing selection is tapped.
  if (event.target.value === state[`${kind}ID`]) goTo('routes', { focusID: `${kind}-picker` });
});
all('[data-setting]').forEach((input) =>
  input.addEventListener('change', () =>
    changeSetting(
      input.dataset.setting,
      input.type === 'checkbox' ? input.checked : Number(input.value),
    ),
  ),
);
$('#result').addEventListener('click', (event) => {
  if (event.target.closest('button')?.id !== 'start-guidance' || !state.route?.ok) return;
  state.steps = guidanceSteps(state.route);
  state.step = 0;
  state.speechPaused = false;
  goTo('guidance');
});
$('#guidance-content').addEventListener('click', (event) => {
  const id = event.target.closest('button')?.id;
  if (id === 'confirm-step' || id === 'previous-step') {
    stopSpeech();
    state.step = moveStep(state.step, id === 'confirm-step' ? 1 : -1, state.steps);
    renderGuidance();
  } else if (id === 'repeat-step') speakStep();
  else if (id === 'pause-speech') {
    state.speechPaused = !state.speechPaused;
    if (state.speechPaused) stopSpeech();
    else speakStep();
    renderGuidance(false);
    $('#pause-speech').focus();
  } else if (id === 'finish-guidance') finishGuidance();
});
$('#end-guidance').addEventListener('click', () => {
  dialog.showModal();
  $('#keep-going').focus();
});
$('#keep-going').addEventListener('click', () => dialog.close());
$('#confirm-end-route').addEventListener('click', finishGuidance);
$('#test-voice').addEventListener('click', () => speak('This is how route directions will sound.'));
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
$('#simulation-details').addEventListener('toggle', () => {
  if (!$('#simulation-details').open) stopSimulation();
});
$('#distance').addEventListener('input', updateDistance);
$('#unreliable').addEventListener('change', updateDistance);
$('.skip-link').addEventListener('click', (event) => {
  event.preventDefault();
  $('#main').focus();
});
window.addEventListener('hashchange', () => showScreen());
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
  ? 'Voice availability depends on your browser and device.'
  : 'Speech is unavailable in this browser. All directions remain visible as text.';
$('#vibration-support').textContent = vibrationSupported
  ? 'This browser exposes vibration. Your hardware may still ignore it.'
  : 'Haptic alerts are unavailable in this browser. Most laptops cannot vibrate.';
all('[data-setting="spokenDirections"], [data-setting="nearbyAudioAlerts"]').forEach((input) => {
  input.disabled = !speechSupported;
});
$('#test-voice').disabled = !speechSupported;
$('[data-setting="nearbyHapticAlerts"]').disabled = !vibrationSupported;
syncSettings();

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
    $('#map-disclaimer').textContent = map.disclaimer;
    $('#map-name').textContent = map.name;
    $('#app').hidden = false;
    syncSettings();
    updateSelections();
    showScreen(false);
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
