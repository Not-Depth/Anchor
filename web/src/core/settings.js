export const SETTINGS_KEY = 'anchor.web.settings.v1';
export const distanceOptions = [0.5, 0.75, 1, 1.5, 2];
export const defaults = Object.freeze({
  requireStepFree: false,
  spokenDirections: false,
  nearbyAudioAlerts: false,
  nearbyHapticAlerts: false,
  nearbyAlertDistance: 1,
  simulateElevatorOutage: false,
});

export function loadSettings(storage) {
  try {
    const saved = JSON.parse(storage.getItem(SETTINGS_KEY));
    const settings = { ...defaults };
    for (const key of Object.keys(defaults)) {
      if (typeof defaults[key] === 'boolean' && typeof saved?.[key] === 'boolean')
        settings[key] = saved[key];
    }
    if (distanceOptions.includes(saved?.nearbyAlertDistance))
      settings.nearbyAlertDistance = saved.nearbyAlertDistance;
    return settings;
  } catch {
    // Private browsing and managed school devices may deny storage access.
    return { ...defaults };
  }
}

export function saveSettings(storage, settings) {
  try {
    storage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    return true;
  } catch {
    return false;
  }
}
